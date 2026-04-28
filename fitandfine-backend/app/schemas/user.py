import uuid
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, ConfigDict


class UserProfileUpdate(BaseModel):
    display_name: Optional[str] = None
    date_of_birth: Optional[date] = None
    sex: Optional[str] = None
    height_cm: Optional[float] = None
    activity_level: Optional[str] = None
    timezone: Optional[str] = None


class UserPreferencesUpdate(BaseModel):
    dietary_restrictions: Optional[list[str]] = None
    allergies: Optional[list[str]] = None
    preferred_cuisine: Optional[list[str]] = None
    budget_per_meal_usd: Optional[float] = None


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: Optional[str] = None
    display_name: Optional[str] = None
    date_of_birth: Optional[date] = None
    sex: Optional[str] = None
    height_cm: Optional[float] = None
    activity_level: Optional[str] = None
    timezone: str
    dietary_restrictions: Optional[list[str]] = None
    allergies: Optional[list[str]] = None
    preferred_cuisine: Optional[list[str]] = None
    budget_per_meal_usd: Optional[float] = None
    created_at: datetime
