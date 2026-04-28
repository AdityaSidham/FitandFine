import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

import httpx
from jose import jwt, JWTError

from app.config import Settings, get_settings


def create_access_token(subject: str, settings: Settings) -> str:
    """Create a short-lived JWT access token."""
    jti = str(uuid.uuid4())
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    payload = {
        "sub": subject,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "jti": jti,
        "type": "access",
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)


def create_refresh_token(subject: str, settings: Settings) -> tuple[str, str]:
    """Create a long-lived refresh token. Returns (token, jti)."""
    jti = str(uuid.uuid4())
    expire = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    payload = {
        "sub": subject,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "jti": jti,
        "type": "refresh",
    }
    token = jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)
    return token, jti


def decode_refresh_token(token: str, settings: Settings) -> dict:
    """Decode and validate a refresh token. Raises JWTError on failure."""
    payload = jwt.decode(token, settings.secret_key, algorithms=[settings.jwt_algorithm])
    if payload.get("type") != "refresh":
        raise JWTError("Not a refresh token")
    return payload


async def verify_apple_identity_token(identity_token: str, bundle_id: str) -> dict:
    """
    Verify Apple Sign In identity token.

    Phase 1: trusts the token structure without full Apple public-key verification
    (Apple keys require a network fetch to https://appleid.apple.com/auth/keys).
    Production: replace with full RS256 verification against Apple's JWKS.
    """
    try:
        # Decode header to get kid — full verification deferred to production
        import base64, json as _json
        parts = identity_token.split(".")
        if len(parts) != 3:
            raise ValueError("Malformed JWT")
        # Decode claims (no signature verification in Phase 1)
        padded = parts[1] + "=" * (4 - len(parts[1]) % 4)
        claims = _json.loads(base64.urlsafe_b64decode(padded))
        # Validate audience matches our bundle ID
        aud = claims.get("aud")
        if bundle_id and aud and aud != bundle_id:
            raise ValueError(f"Token audience {aud!r} does not match bundle_id {bundle_id!r}")
        return claims
    except Exception as e:
        raise ValueError(f"Invalid Apple identity token: {e}")


async def verify_google_id_token(id_token: str, client_id: str) -> dict:
    """
    Verify Google ID token via Google's tokeninfo endpoint.
    """
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": id_token},
        )
        if response.status_code != 200:
            raise ValueError("Invalid Google ID token")
        data = response.json()
        if client_id and data.get("aud") != client_id:
            raise ValueError("Google token audience mismatch")
        return data
