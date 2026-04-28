import uuid
from datetime import date
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_db, get_current_user_id
from app.repositories.goal_repository import GoalRepository
from app.repositories.user_repository import UserRepository
from app.repositories.weight_repository import WeightRepository
from app.schemas.goal import CreateGoalRequest, GoalResponse
from app.services.macro_service import compute_goal_targets, calculate_macro_grams, get_default_macro_split

router = APIRouter()


@router.get("/history", response_model=list[GoalResponse])
async def get_goal_history(
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db)],
) -> list[GoalResponse]:
    """Return the authenticated user's goal history (most recent first)."""
    repo = GoalRepository(session)
    goals = await repo.get_goal_history(user_id)
    return [GoalResponse.model_validate(g, from_attributes=True) for g in goals]


@router.get("/", response_model=GoalResponse)
async def get_active_goal(
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db)],
) -> GoalResponse:
    """Return the user's currently active goal."""
    repo = GoalRepository(session)
    goal = await repo.get_active_goal(user_id)
    if goal is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active goal found. Create one first.",
        )
    return GoalResponse.model_validate(goal, from_attributes=True)


@router.post("/", response_model=GoalResponse, status_code=status.HTTP_201_CREATED)
async def create_goal(
    body: CreateGoalRequest,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db)],
) -> GoalResponse:
    """Create a new goal and deactivate any existing ones.

    Calorie and macro targets are computed from the user's biometric profile
    (Mifflin-St Jeor BMR + TDEE adjustment) when available. Custom overrides
    are accepted via the request body.
    """
    goal_repo = GoalRepository(session)
    user_repo = UserRepository(session)
    weight_repo = WeightRepository(session)

    # Load user profile for BMR/TDEE computation.
    user = await user_repo.get_active_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    # Resolve current weight from the most recent weight log.
    latest_weight_log = await weight_repo.get_latest(user_id)
    weight_kg: Optional[float] = (
        float(latest_weight_log.weight_kg) if latest_weight_log else None
    )

    # Helper flags.
    has_full_profile = all([
        weight_kg is not None,
        user.height_cm is not None,
        user.date_of_birth is not None,
        user.sex is not None,
        user.activity_level is not None,
    ])

    if has_full_profile and body.calorie_target is None:
        # Compute everything from biometrics.
        targets = compute_goal_targets(
            weight_kg=weight_kg,
            height_cm=float(user.height_cm),
            date_of_birth=user.date_of_birth,
            sex=user.sex,
            activity_level=user.activity_level,
            goal_type=body.goal_type,
            custom_protein_pct=body.protein_pct,
            custom_carb_pct=body.carb_pct,
            custom_fat_pct=body.fat_pct,
        )
        calorie_target: int = targets["calorie_target"]
        protein_pct: float = targets["protein_pct"]
        carb_pct: float = targets["carb_pct"]
        fat_pct: float = targets["fat_pct"]
        protein_g: float = targets["protein_g"]
        carb_g: float = targets["carb_g"]
        fat_g: float = targets["fat_g"]

    elif body.calorie_target is not None:
        # User supplied a custom calorie target; use provided or default macros.
        calorie_target = body.calorie_target
        if body.protein_pct is not None:
            protein_pct = body.protein_pct
            carb_pct = body.carb_pct
            fat_pct = body.fat_pct
        else:
            split = get_default_macro_split(body.goal_type)
            protein_pct = split["protein_pct"]
            carb_pct = split["carb_pct"]
            fat_pct = split["fat_pct"]

        macro_grams = calculate_macro_grams(calorie_target, protein_pct, carb_pct, fat_pct)
        protein_g = macro_grams["protein_g"]
        carb_g = macro_grams["carb_g"]
        fat_g = macro_grams["fat_g"]

    else:
        # Fallback: incomplete profile + no custom calorie target.
        calorie_target = 2000
        split = get_default_macro_split(body.goal_type)
        protein_pct = split["protein_pct"]
        carb_pct = split["carb_pct"]
        fat_pct = split["fat_pct"]
        macro_grams = calculate_macro_grams(calorie_target, protein_pct, carb_pct, fat_pct)
        protein_g = macro_grams["protein_g"]
        carb_g = macro_grams["carb_g"]
        fat_g = macro_grams["fat_g"]

    # Deactivate any previously active goals before creating a new one.
    await goal_repo.deactivate_all_goals(user_id)

    new_goal = await goal_repo.create(
        user_id=user_id,
        goal_type=body.goal_type,
        calorie_target=calorie_target,
        is_active=True,
        protein_pct=protein_pct,
        carb_pct=carb_pct,
        fat_pct=fat_pct,
        protein_g=protein_g,
        carb_g=carb_g,
        fat_g=fat_g,
        target_weight_kg=body.target_weight_kg,
        target_date=body.target_date,
        weekly_weight_change_target_kg=body.weekly_weight_change_target_kg,
    )

    return GoalResponse.model_validate(new_goal, from_attributes=True)


@router.put("/{goal_id}", response_model=GoalResponse)
async def update_goal(
    goal_id: uuid.UUID,
    body: CreateGoalRequest,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    session: Annotated[AsyncSession, Depends(get_db)],
) -> GoalResponse:
    """Update an existing goal by ID.

    When calorie_target changes, macro gram targets are recomputed automatically
    using the goal's current percentage splits.
    """
    repo = GoalRepository(session)
    goal = await repo.get_by_id(goal_id)

    if goal is None or goal.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Goal not found.",
        )

    # Build the fields to update from the request body.
    updated_fields: dict = {
        "goal_type": body.goal_type,
        "target_weight_kg": body.target_weight_kg,
        "target_date": body.target_date,
        "weekly_weight_change_target_kg": body.weekly_weight_change_target_kg,
    }

    # Resolve new calorie target and macro pcts.
    new_calorie_target: int = (
        body.calorie_target if body.calorie_target is not None
        else (goal.calorie_target if goal.calorie_target is not None else 2000)
    )
    calorie_changed = new_calorie_target != goal.calorie_target

    if body.protein_pct is not None:
        new_protein_pct = body.protein_pct
        new_carb_pct = body.carb_pct
        new_fat_pct = body.fat_pct
    else:
        # Retain existing pcts or fall back to goal-type defaults.
        existing_split = (
            {
                "protein_pct": float(goal.protein_pct),
                "carb_pct": float(goal.carb_pct),
                "fat_pct": float(goal.fat_pct),
            }
            if goal.protein_pct is not None
            else get_default_macro_split(body.goal_type)
        )
        new_protein_pct = existing_split["protein_pct"]
        new_carb_pct = existing_split["carb_pct"]
        new_fat_pct = existing_split["fat_pct"]

    updated_fields["calorie_target"] = new_calorie_target
    updated_fields["protein_pct"] = new_protein_pct
    updated_fields["carb_pct"] = new_carb_pct
    updated_fields["fat_pct"] = new_fat_pct

    # Recompute macro grams whenever calorie target or pcts change.
    if calorie_changed or body.protein_pct is not None:
        macro_grams = calculate_macro_grams(
            new_calorie_target, new_protein_pct, new_carb_pct, new_fat_pct
        )
        updated_fields["protein_g"] = macro_grams["protein_g"]
        updated_fields["carb_g"] = macro_grams["carb_g"]
        updated_fields["fat_g"] = macro_grams["fat_g"]

    updated_goal = await repo.update(goal, **updated_fields)
    return GoalResponse.model_validate(updated_goal, from_attributes=True)
