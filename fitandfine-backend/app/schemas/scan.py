"""Pydantic schemas for Phase 2 scan endpoints."""
from typing import Optional
import uuid

from pydantic import BaseModel

from app.schemas.food import FoodItemCreate, FoodItemResponse


class LabelScanResult(BaseModel):
    """Internal result from LabelScanService — not exposed directly as API response."""
    food: FoodItemCreate
    confidence: float  # 0.0 – 1.0


class LabelScanResponse(BaseModel):
    """Response from POST /scan/label."""
    scan_id: str
    food: FoodItemCreate
    confidence: float
    message: str


class ConfirmScanRequest(BaseModel):
    """User-confirmed (possibly edited) food after reviewing scan result."""
    scan_id: Optional[str] = None
    food: FoodItemCreate


class ConfirmScanResponse(BaseModel):
    """Response from POST /scan/confirm — the saved food item's UUID."""
    food_item_id: str
    message: str


class BarcodeScanResponse(BaseModel):
    found: bool
    food_item: Optional[FoodItemResponse] = None
    source: Optional[str] = None


class ScanHistoryItem(BaseModel):
    scan_id: str
    scan_type: str          # nutrition_label | barcode
    status: str             # complete | failed | processing
    confidence: Optional[float] = None
    food_name: Optional[str] = None
    created_at: str
