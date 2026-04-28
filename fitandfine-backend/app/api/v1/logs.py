"""
Food logging router — daily log CRUD with macro computation and Redis caching.
All endpoints require a valid JWT.
"""
import json
import logging
import uuid
from datetime import date, datetime, timezone
from typing import Annotated, Optional

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user_id, get_db, get_redis
from app.repositories.food_repository import FoodRepository
from app.repositories.goal_repository import GoalRepository
from app.repositories.log_repository import LogRepository
from app.schemas.log import (
    AddFoodLogRequest,
    DailyLogResponse,
    DailyMacroTotals,
    FoodLogEntryResponse,
    UpdateFoodLogRequest,
)
from app.services.cache_service import CacheService

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _compute_macros(food_item, quantity: float) -> dict:
    """Scale denormalized nutrition values by quantity multiplier."""
    def _scale(value) -> float:
        if value is None:
            return 0.0
        return float(value) * quantity

    return {
        "calories_consumed": _scale(food_item.calories),
        "protein_consumed_g": _scale(food_item.protein_g),
        "carbs_consumed_g": _scale(food_item.carbohydrates_g),
        "fat_consumed_g": _scale(food_item.fat_g),
    }


def _group_by_meal(entries: list[FoodLogEntryResponse]) -> dict[str, list[FoodLogEntryResponse]]:
    """Bucket log entries by meal_type."""
    groups: dict[str, list[FoodLogEntryResponse]] = {}
    for entry in entries:
        groups.setdefault(entry.meal_type, []).append(entry)
    return groups


# ---------------------------------------------------------------------------
# GET /daily
# ---------------------------------------------------------------------------

@router.get(
    "/daily",
    response_model=DailyLogResponse,
    status_code=status.HTTP_200_OK,
    summary="Get daily food log",
)
async def get_daily_log(
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
    log_date: Annotated[Optional[date], Query(description="ISO date (YYYY-MM-DD). Defaults to today.")] = None,
) -> DailyLogResponse:
    """Return all food log entries for a given date, with macro totals and goal targets."""
    target_date = log_date or date.today()

    cache = CacheService(redis)
    log_repo = LogRepository(db)
    goal_repo = GoalRepository(db)

    # 1. Load daily log entries from DB
    entries = await log_repo.get_daily_logs(user_id=user_id, log_date=target_date)
    entry_responses = [
        FoodLogEntryResponse.model_validate(e, from_attributes=True) for e in entries
    ]

    # 2. Macro totals — check Redis first
    cached_totals = await cache.get_daily_macros(user_id=str(user_id), date_str=str(target_date))
    if cached_totals is not None:
        try:
            totals_data = json.loads(cached_totals) if isinstance(cached_totals, str) else cached_totals
            totals = DailyMacroTotals(date=target_date, **totals_data)
        except Exception:
            totals = None
    else:
        totals = None

    if totals is None:
        totals_dict = await log_repo.get_daily_totals(user_id=user_id, log_date=target_date)
        totals = DailyMacroTotals(date=target_date, **totals_dict)
        # Cache the totals
        try:
            await cache.set_daily_macros(
                user_id=str(user_id),
                date_str=str(target_date),
                totals=totals_dict,
            )
        except Exception as exc:
            logger.warning("Failed to cache daily macros: %s", exc)

    # 3. Active goal for target comparison
    active_goal = await goal_repo.get_active_goal(user_id=user_id)

    return DailyLogResponse(
        date=target_date,
        totals=totals,
        goal_calories=float(active_goal.calorie_target) if active_goal and active_goal.calorie_target else None,
        goal_protein_g=float(active_goal.protein_g) if active_goal and active_goal.protein_g else None,
        goal_carbs_g=float(active_goal.carb_g) if active_goal and active_goal.carb_g else None,
        goal_fat_g=float(active_goal.fat_g) if active_goal and active_goal.fat_g else None,
        entries=entry_responses,
        entries_by_meal=_group_by_meal(entry_responses),
    )


# ---------------------------------------------------------------------------
# POST /daily
# ---------------------------------------------------------------------------

@router.post(
    "/daily",
    response_model=FoodLogEntryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add food log entry",
)
async def add_food_log(
    body: AddFoodLogRequest,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
) -> FoodLogEntryResponse:
    """Log a food item with quantity; macros are auto-computed from the food item."""
    food_repo = FoodRepository(db)
    log_repo = LogRepository(db)
    cache = CacheService(redis)

    # Verify the food item exists
    food_item = await food_repo.get_by_id(body.food_item_id)
    if food_item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Food item {body.food_item_id} not found",
        )

    # Compute consumed macros
    macros = _compute_macros(food_item, body.quantity)

    # Strip tzinfo — PostgreSQL columns are TIMESTAMP WITHOUT TIME ZONE
    raw_log_time = body.log_time or datetime.now(timezone.utc)
    log_time = raw_log_time.replace(tzinfo=None) if raw_log_time.tzinfo else raw_log_time

    new_entry = await log_repo.create(
        user_id=user_id,
        food_item_id=body.food_item_id,
        log_date=body.log_date,
        log_time=log_time,
        meal_type=body.meal_type,
        quantity=body.quantity,
        serving_description=body.serving_description,
        entry_method=body.entry_method or "manual",
        scan_id=body.scan_id,
        notes=body.notes,
        **macros,
    )

    # Invalidate daily macro cache for this date
    await cache.invalidate_daily_macros(
        user_id=str(user_id), date_str=str(body.log_date)
    )

    return FoodLogEntryResponse.model_validate(new_entry, from_attributes=True)


# ---------------------------------------------------------------------------
# PUT /daily/{log_id}
# ---------------------------------------------------------------------------

@router.put(
    "/daily/{log_id}",
    response_model=FoodLogEntryResponse,
    status_code=status.HTTP_200_OK,
    summary="Update food log entry",
)
async def update_food_log(
    log_id: uuid.UUID,
    body: UpdateFoodLogRequest,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
) -> FoodLogEntryResponse:
    """Partial-update a log entry; recomputes macros if quantity changes."""
    log_repo = LogRepository(db)
    cache = CacheService(redis)

    log_entry = await log_repo.get_by_id_for_user(log_id=log_id, user_id=user_id)
    if log_entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Log entry {log_id} not found",
        )

    updates = body.model_dump(exclude_none=True)

    # Recompute macros if quantity changed
    if "quantity" in updates:
        food_repo = FoodRepository(db)
        food_item = await food_repo.get_by_id(log_entry.food_item_id)
        if food_item is not None:
            macros = _compute_macros(food_item, updates["quantity"])
            updates.update(macros)

    if updates:
        log_entry = await log_repo.update(log_entry, **updates)

    # Invalidate cache for the log date
    await cache.invalidate_daily_macros(
        user_id=str(user_id), date_str=str(log_entry.log_date)
    )

    return FoodLogEntryResponse.model_validate(log_entry, from_attributes=True)


# ---------------------------------------------------------------------------
# DELETE /daily/{log_id}
# ---------------------------------------------------------------------------

@router.delete(
    "/daily/{log_id}",
    status_code=status.HTTP_200_OK,
    summary="Delete food log entry (soft delete)",
)
async def delete_food_log(
    log_id: uuid.UUID,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
) -> dict:
    """Soft-delete a log entry and invalidate the daily macro cache."""
    log_repo = LogRepository(db)
    cache = CacheService(redis)

    log_entry = await log_repo.get_by_id_for_user(log_id=log_id, user_id=user_id)
    if log_entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Log entry {log_id} not found",
        )

    log_date_str = str(log_entry.log_date)
    await log_repo.soft_delete(log_entry)

    # Invalidate daily macro cache
    await cache.invalidate_daily_macros(user_id=str(user_id), date_str=log_date_str)

    return {"message": "Log entry deleted"}


# ---------------------------------------------------------------------------
# GET /analytics
# ---------------------------------------------------------------------------

@router.get(
    "/analytics",
    status_code=status.HTTP_200_OK,
    summary="Get macro analytics for a date range",
)
async def get_log_analytics(
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
    days: int = Query(default=30, ge=1, le=365, description="Number of days to look back"),
) -> dict:
    """Return per-day macro totals and averages for the last N days."""
    from datetime import timedelta
    end_date = date.today()
    start_date = end_date - timedelta(days=days - 1)

    log_repo = LogRepository(db)
    daily_totals = await log_repo.get_range_daily_totals(user_id, start_date, end_date)

    logged_days = [d for d in daily_totals if d["entries_count"] > 0]
    n = max(len(logged_days), 1)

    return {
        "daily_totals": daily_totals,
        "logged_days": len(logged_days),
        "total_days": days,
        "avg_calories": round(sum(d["calories"] for d in logged_days) / n, 1),
        "avg_protein_g": round(sum(d["protein_g"] for d in logged_days) / n, 1),
        "avg_carbs_g": round(sum(d["carbs_g"] for d in logged_days) / n, 1),
        "avg_fat_g": round(sum(d["fat_g"] for d in logged_days) / n, 1),
    }
