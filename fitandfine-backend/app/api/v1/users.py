"""
User profile router — get/update profile, preferences, soft-delete.
All endpoints require a valid JWT.
"""
import logging
import uuid
from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user_id, get_db
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserPreferencesUpdate, UserProfileUpdate, UserResponse

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# GET /me
# ---------------------------------------------------------------------------

@router.get(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current user profile",
)
async def get_current_user(
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> UserResponse:
    """Return the authenticated user's profile."""
    repo = UserRepository(db)
    user = await repo.get_active_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return UserResponse.model_validate(user, from_attributes=True)


# ---------------------------------------------------------------------------
# PUT /me
# ---------------------------------------------------------------------------

@router.put(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Update user profile",
)
async def update_profile(
    body: UserProfileUpdate,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> UserResponse:
    """Partial-update the authenticated user's core profile fields."""
    repo = UserRepository(db)
    user = await repo.get_active_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Only update fields that were explicitly provided
    updates = body.model_dump(exclude_none=True)
    if not updates:
        return UserResponse.model_validate(user, from_attributes=True)

    user = await repo.update(user, **updates)
    return UserResponse.model_validate(user, from_attributes=True)


# ---------------------------------------------------------------------------
# PUT /me/preferences
# ---------------------------------------------------------------------------

@router.put(
    "/me/preferences",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Update dietary preferences",
)
async def update_preferences(
    body: UserPreferencesUpdate,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> UserResponse:
    """Update dietary restrictions, allergies, cuisine prefs, and meal budget."""
    repo = UserRepository(db)
    user = await repo.get_active_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    updates = body.model_dump(exclude_none=True)
    if not updates:
        return UserResponse.model_validate(user, from_attributes=True)

    user = await repo.update(user, **updates)
    return UserResponse.model_validate(user, from_attributes=True)


# ---------------------------------------------------------------------------
# DELETE /me
# ---------------------------------------------------------------------------

@router.delete(
    "/me",
    status_code=status.HTTP_200_OK,
    summary="Soft-delete account (GDPR)",
)
async def delete_account(
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict:
    """Mark the user's account for deletion (soft delete — GDPR compliant)."""
    repo = UserRepository(db)
    user = await repo.get_active_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    await repo.soft_delete(user)
    logger.info("User %s scheduled for deletion", user_id)
    return {"message": "Account scheduled for deletion"}
