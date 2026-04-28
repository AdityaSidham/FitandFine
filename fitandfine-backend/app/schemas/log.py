import uuid
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, field_validator


class AddFoodLogRequest(BaseModel):
    food_item_id: uuid.UUID
    log_date: date
    log_time: Optional[datetime] = None
    meal_type: str  # breakfast, lunch, dinner, snack, drink
    quantity: float  # multiplier of serving size
    serving_description: Optional[str] = None
    entry_method: Optional[str] = "manual"
    scan_id: Optional[uuid.UUID] = None
    notes: Optional[str] = None

    @field_validator("meal_type")
    @classmethod
    def validate_meal_type(cls, v: str) -> str:
        allowed = {"breakfast", "lunch", "dinner", "snack", "drink"}
        if v not in allowed:
            raise ValueError(f"meal_type must be one of {allowed}")
        return v

    @field_validator("quantity")
    @classmethod
    def validate_quantity(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("quantity must be positive")
        return v


class UpdateFoodLogRequest(BaseModel):
    quantity: Optional[float] = None
    meal_type: Optional[str] = None
    notes: Optional[str] = None


class FoodLogEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    food_item_id: uuid.UUID
    # food_item relationship is intentionally excluded —
    # iOS fetches food details via GET /foods/{food_item_id} when needed.
    log_date: date
    log_time: datetime
    meal_type: str
    quantity: float
    serving_description: Optional[str] = None
    calories_consumed: float
    protein_consumed_g: float
    carbs_consumed_g: float
    fat_consumed_g: float
    entry_method: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime


class DailyMacroTotals(BaseModel):
    date: date
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    entries_count: int


class DailyLogResponse(BaseModel):
    date: date
    totals: DailyMacroTotals
    goal_calories: Optional[float] = None
    goal_protein_g: Optional[float] = None
    goal_carbs_g: Optional[float] = None
    goal_fat_g: Optional[float] = None
    entries: list[FoodLogEntryResponse]
    entries_by_meal: dict[str, list[FoodLogEntryResponse]]
