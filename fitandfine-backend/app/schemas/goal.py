import uuid
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, field_validator, model_validator


class CreateGoalRequest(BaseModel):
    goal_type: str  # lose_weight, maintain, gain_muscle, recomp
    target_weight_kg: Optional[float] = None
    target_date: Optional[date] = None
    weekly_weight_change_target_kg: Optional[float] = None
    # If not provided, backend calculates from BMR/TDEE
    calorie_target: Optional[int] = None
    protein_pct: Optional[float] = None
    carb_pct: Optional[float] = None
    fat_pct: Optional[float] = None

    @field_validator("goal_type")
    @classmethod
    def validate_goal_type(cls, v: str) -> str:
        allowed = {"lose_weight", "maintain", "gain_muscle", "recomp"}
        if v not in allowed:
            raise ValueError(f"goal_type must be one of {allowed}")
        return v

    @model_validator(mode="after")
    def validate_macro_pcts(self) -> "CreateGoalRequest":
        pcts = [self.protein_pct, self.carb_pct, self.fat_pct]
        if any(p is not None for p in pcts):
            if not all(p is not None for p in pcts):
                raise ValueError("All three macro percentages must be provided together")
            total = sum(pcts)
            if not (98 <= total <= 102):
                raise ValueError(f"Macro percentages must sum to 100 (got {total})")
        return self


class GoalResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    goal_type: str
    target_weight_kg: Optional[float] = None
    target_date: Optional[date] = None
    calorie_target: Optional[int] = None
    protein_pct: Optional[float] = None
    carb_pct: Optional[float] = None
    fat_pct: Optional[float] = None
    protein_g: Optional[float] = None
    carb_g: Optional[float] = None
    fat_g: Optional[float] = None
    weekly_weight_change_target_kg: Optional[float] = None
    is_active: bool
    created_at: datetime
