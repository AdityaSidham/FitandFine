"""
Authentication router — Apple Sign In, Google Sign In, token refresh, logout.
"""
import logging
import uuid
from typing import Annotated

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.dependencies import get_db, get_redis
from app.repositories.user_repository import UserRepository
from app.schemas.auth import (
    AppleSignInRequest,
    GoogleSignInRequest,
    LogoutRequest,
    RefreshTokenRequest,
    TokenResponse,
)
from app.services.auth_service import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    verify_apple_identity_token,
    verify_google_id_token,
)
from app.services.cache_service import CacheService

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Dev Login  (development environment only — bypasses OAuth)
# ---------------------------------------------------------------------------

@router.post(
    "/dev-login",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="[DEV ONLY] Create/return a test user without OAuth",
    include_in_schema=True,
)
async def dev_login(
    db: Annotated[AsyncSession, Depends(get_db)],
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenResponse:
    """
    Development-only endpoint.
    Creates a deterministic test user (dev@fitandfine.test) and returns
    a real JWT pair so the iOS Simulator can skip Apple/Google OAuth.
    Returns 403 in production.
    """
    if settings.environment != "development":
        from fastapi import HTTPException as _HTTP
        raise _HTTP(status_code=status.HTTP_403_FORBIDDEN, detail="Not available in production")

    repo = UserRepository(db)
    dev_apple_id = "dev_simulator_user_001"
    user = await repo.get_by_apple_id(dev_apple_id)
    if user is None:
        user = await repo.create(
            apple_user_id=dev_apple_id,
            email="dev@fitandfine.test",
            display_name="Dev Tester",
        )
        logger.info("Created dev test user: %s", user.id)
    else:
        logger.info("Returning existing dev test user: %s", user.id)

    access_token = create_access_token(subject=str(user.id), settings=settings)
    refresh_token, refresh_jti = create_refresh_token(subject=str(user.id), settings=settings)

    cache = CacheService(redis)
    await cache.store_refresh_token(
        user_id=str(user.id),
        jti=refresh_jti,
        ttl_seconds=settings.refresh_token_expire_days * 86400,
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60,
    )


# ---------------------------------------------------------------------------
# Apple Sign In
# ---------------------------------------------------------------------------

@router.post(
    "/apple",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Sign in with Apple",
)
async def apple_sign_in(
    payload: AppleSignInRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenResponse:
    """Verify Apple identity token, create/fetch user, return JWT pair."""
    # 1. Verify the Apple identity token
    try:
        apple_claims = await verify_apple_identity_token(
            identity_token=payload.identity_token,
            bundle_id=settings.apple_app_bundle_id,
        )
    except Exception as exc:
        logger.warning("Apple identity token verification failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Apple identity token",
        )

    apple_user_id: str = apple_claims.get("sub") or payload.user_identifier

    # 2. Find or create the user
    repo = UserRepository(db)
    user = await repo.get_by_apple_id(apple_user_id)
    if user is None:
        create_kwargs: dict = {"apple_user_id": apple_user_id}
        if payload.email:
            create_kwargs["email"] = payload.email
        if payload.display_name:
            create_kwargs["display_name"] = payload.display_name
        user = await repo.create(**create_kwargs)
        logger.info("Created new user via Apple Sign In: %s", user.id)
    else:
        # Backfill email / display_name on subsequent logins if newly supplied
        updates: dict = {}
        if payload.email and not user.email:
            updates["email"] = payload.email
        if payload.display_name and not user.display_name:
            updates["display_name"] = payload.display_name
        if updates:
            user = await repo.update(user, **updates)

    # 3. Issue tokens
    access_token = create_access_token(
        subject=str(user.id), settings=settings
    )
    refresh_token, refresh_jti = create_refresh_token(
        subject=str(user.id), settings=settings
    )

    # 4. Persist refresh JTI in Redis
    cache = CacheService(redis)
    await cache.store_refresh_token(
        user_id=str(user.id),
        jti=refresh_jti,
        ttl_seconds=settings.refresh_token_expire_days * 86400,
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60,
    )


# ---------------------------------------------------------------------------
# Google Sign In
# ---------------------------------------------------------------------------

@router.post(
    "/google",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Sign in with Google",
)
async def google_sign_in(
    payload: GoogleSignInRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenResponse:
    """Verify Google ID token, create/fetch user, return JWT pair."""
    # 1. Verify the Google ID token
    try:
        google_claims = await verify_google_id_token(
            id_token=payload.id_token,
            client_id=settings.google_client_id,
        )
    except Exception as exc:
        logger.warning("Google ID token verification failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google ID token",
        )

    google_user_id: str = google_claims["sub"]
    email = google_claims.get("email")
    display_name = google_claims.get("name")

    # 2. Find or create the user
    repo = UserRepository(db)
    user = await repo.get_by_google_id(google_user_id)
    if user is None:
        create_kwargs: dict = {"google_user_id": google_user_id}
        if email:
            create_kwargs["email"] = email
        if display_name:
            create_kwargs["display_name"] = display_name
        user = await repo.create(**create_kwargs)
        logger.info("Created new user via Google Sign In: %s", user.id)
    else:
        updates: dict = {}
        if email and not user.email:
            updates["email"] = email
        if display_name and not user.display_name:
            updates["display_name"] = display_name
        if updates:
            user = await repo.update(user, **updates)

    # 3. Issue tokens
    access_token = create_access_token(
        subject=str(user.id), settings=settings
    )
    refresh_token, refresh_jti = create_refresh_token(
        subject=str(user.id), settings=settings
    )

    # 4. Persist refresh JTI in Redis
    cache = CacheService(redis)
    await cache.store_refresh_token(
        user_id=str(user.id),
        jti=refresh_jti,
        ttl_seconds=settings.refresh_token_expire_days * 86400,
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60,
    )


# ---------------------------------------------------------------------------
# Token Refresh
# ---------------------------------------------------------------------------

@router.post(
    "/refresh",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Refresh access token",
)
async def refresh_token(
    payload: RefreshTokenRequest,
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> TokenResponse:
    """Exchange a valid refresh token for a new token pair."""
    # 1. Decode and validate refresh token structure
    try:
        claims = decode_refresh_token(
            token=payload.refresh_token, settings=settings
        )
    except Exception as exc:
        logger.debug("Refresh token decode failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    user_id: str = claims["sub"]
    jti: str = claims["jti"]

    # 2. Verify the JTI exists in Redis (not revoked)
    cache = CacheService(redis)
    is_valid = await cache.validate_refresh_token(user_id=user_id, jti=jti)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has been revoked",
        )

    # 3. Revoke the old refresh token (rotation)
    await cache.revoke_refresh_token(user_id=user_id, jti=jti)

    # 4. Issue a fresh token pair
    new_access_token = create_access_token(subject=user_id, settings=settings)
    new_refresh_token, new_refresh_jti = create_refresh_token(
        subject=user_id, settings=settings
    )

    await cache.store_refresh_token(
        user_id=user_id,
        jti=new_refresh_jti,
        ttl_seconds=settings.refresh_token_expire_days * 86400,
    )

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60,
    )


# ---------------------------------------------------------------------------
# Logout
# ---------------------------------------------------------------------------

@router.post(
    "/logout",
    status_code=status.HTTP_200_OK,
    summary="Logout — revoke refresh token",
)
async def logout(
    payload: LogoutRequest,
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    """Revoke the supplied refresh token from Redis."""
    try:
        claims = decode_refresh_token(
            token=payload.refresh_token, settings=settings
        )
    except Exception:
        # Even on failure, return success so clients can clear local state
        return {"message": "Logged out"}

    user_id: str = claims["sub"]
    jti: str = claims["jti"]

    cache = CacheService(redis)
    await cache.revoke_refresh_token(user_id=user_id, jti=jti)

    return {"message": "Logged out"}
