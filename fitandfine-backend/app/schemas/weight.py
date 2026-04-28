import uuid
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class AddWeightLogRequest(BaseModel):
    log_date: date
    log_time: Optional[datetime] = None
    weight_kg: float
    body_fat_pct: Optional[float] = None
    muscle_mass_kg: Optional[float] = None
    water_pct: Optional[float] = None
    measurement_source: Optional[str] = "manual"
    notes: Optional[str] = None


class UpdateWeightLogRequest(BaseModel):
    weight_kg: Optional[float] = None
    body_fat_pct: Optional[float] = None
    notes: Optional[str] = None


class WeightLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    log_date: date
    log_time: datetime
    weight_kg: float
    body_fat_pct: Optional[float] = None
    muscle_mass_kg: Optional[float] = None
    measurement_source: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime


class WeightHistoryResponse(BaseModel):
    entries: list[WeightLogResponse]
    current_weight_kg: Optional[float] = None
    starting_weight_kg: Optional[float] = None
    total_change_kg: Optional[float] = None
    weekly_rate_kg: Optional[float] = None  # avg kg/week over the period
    trend_direction: Optional[str] = None  # losing, gaining, maintaining
