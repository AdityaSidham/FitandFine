import uuid
from datetime import date, datetime, timezone
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, get_current_user_id
from app.repositories.weight_repository import WeightRepository
from app.schemas.weight import (
    AddWeightLogRequest,
    UpdateWeightLogRequest,
    WeightLogResponse,
    WeightHistoryResponse,
)

router = APIRouter()


@router.post("/", response_model=WeightLogResponse, status_code=status.HTTP_201_CREATED)
async def log_weight(
    body: AddWeightLogRequest,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db)],
) -> WeightLogResponse:
    """Record a new weight reading for today or a back-dated entry.

    Returns 409 if a reading already exists for the given date; callers should
    use PUT /{log_id} to amend an existing entry.
    """
    repo = WeightRepository(session)

    existing = await repo.get_by_date(user_id, body.log_date)
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Weight already logged for this date. Use PUT to update.",
        )

    # Strip tzinfo — PostgreSQL columns are TIMESTAMP WITHOUT TIME ZONE
    raw_log_time = body.log_time or datetime.now(timezone.utc)
    log_time: datetime = raw_log_time.replace(tzinfo=None) if raw_log_time.tzinfo else raw_log_time

    new_log = await repo.create(
        user_id=user_id,
        log_date=body.log_date,
        log_time=log_time,
        weight_kg=body.weight_kg,
        body_fat_pct=body.body_fat_pct,
        muscle_mass_kg=body.muscle_mass_kg,
        water_pct=body.water_pct,
        measurement_source=body.measurement_source or "manual",
        notes=body.notes,
    )

    return WeightLogResponse.model_validate(new_log, from_attributes=True)


@router.get("/history", response_model=WeightHistoryResponse)
async def get_weight_history(
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db)],
    days: int = Query(default=90, ge=1, le=3650, description="Number of calendar days to look back"),
) -> WeightHistoryResponse:
    """Return weight entries for the requested window together with trend stats."""
    repo = WeightRepository(session)
    entries = await repo.get_history(user_id, days)

    # Scalar stats.
    current_weight_kg: Optional[float] = float(entries[-1].weight_kg) if entries else None
    starting_weight_kg: Optional[float] = float(entries[0].weight_kg) if entries else None
    total_change_kg: Optional[float] = None
    weekly_rate_kg: Optional[float] = None
    trend_direction: Optional[str] = None

    if current_weight_kg is not None and starting_weight_kg is not None:
        total_change_kg = round(current_weight_kg - starting_weight_kg, 2)

        if len(entries) >= 2:
            days_span = (entries[-1].log_date - entries[0].log_date).days
            if days_span > 0:
                weekly_rate_kg = round(total_change_kg / (days_span / 7), 2)

    if weekly_rate_kg is not None:
        if weekly_rate_kg < -0.1:
            trend_direction = "losing"
        elif weekly_rate_kg > 0.1:
            trend_direction = "gaining"
        else:
            trend_direction = "maintaining"
    elif entries:
        # Single entry — no trend computable; treat as maintaining.
        trend_direction = "maintaining"

    return WeightHistoryResponse(
        entries=[WeightLogResponse.model_validate(e, from_attributes=True) for e in entries],
        current_weight_kg=current_weight_kg,
        starting_weight_kg=starting_weight_kg,
        total_change_kg=total_change_kg,
        weekly_rate_kg=weekly_rate_kg,
        trend_direction=trend_direction,
    )


@router.get("/latest", response_model=WeightLogResponse)
async def get_latest_weight(
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db)],
) -> WeightLogResponse:
    """Return the most recent weight log entry."""
    repo = WeightRepository(session)
    log = await repo.get_latest(user_id)
    if log is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No weight logs found for this user.",
        )
    return WeightLogResponse.model_validate(log, from_attributes=True)


@router.put("/{log_id}", response_model=WeightLogResponse)
async def update_weight_log(
    log_id: uuid.UUID,
    body: UpdateWeightLogRequest,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db)],
) -> WeightLogResponse:
    """Amend an existing weight log entry.

    Only the fields explicitly set in the request body are updated; omitted
    optional fields retain their current values.
    """
    repo = WeightRepository(session)
    log = await repo.get_by_id(log_id)

    if log is None or log.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Weight log not found.",
        )

    # Apply only the non-None fields supplied by the caller.
    updates: dict = {}
    if body.weight_kg is not None:
        updates["weight_kg"] = body.weight_kg
    if body.body_fat_pct is not None:
        updates["body_fat_pct"] = body.body_fat_pct
    if body.notes is not None:
        updates["notes"] = body.notes

    if updates:
        log = await repo.update(log, **updates)

    return WeightLogResponse.model_validate(log, from_attributes=True)
