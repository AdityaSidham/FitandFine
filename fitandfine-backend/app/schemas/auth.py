from typing import Optional
from pydantic import BaseModel, EmailStr


class AppleSignInRequest(BaseModel):
    identity_token: str
    user_identifier: str
    display_name: Optional[str] = None
    email: Optional[str] = None


class GoogleSignInRequest(BaseModel):
    id_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # seconds


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str
