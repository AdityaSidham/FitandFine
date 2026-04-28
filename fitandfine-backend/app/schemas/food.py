import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict


class FoodItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    brand: Optional[str] = None
    barcode: Optional[str] = None
    source: str
    serving_size_g: Optional[float] = None
    serving_size_description: Optional[str] = None
    calories: Optional[float] = None
    protein_g: Optional[float] = None
    carbohydrates_g: Optional[float] = None
    fat_g: Optional[float] = None
    fiber_g: Optional[float] = None
    sugar_g: Optional[float] = None
    sodium_mg: Optional[float] = None
    saturated_fat_g: Optional[float] = None
    allergen_flags: Optional[list[str]] = None
    is_verified: bool
    confidence_score: Optional[float] = None


class FoodItemCreate(BaseModel):
    name: str
    brand: Optional[str] = None
    serving_size_g: Optional[float] = None
    serving_size_description: Optional[str] = None
    calories: Optional[float] = None
    protein_g: Optional[float] = None
    carbohydrates_g: Optional[float] = None
    fat_g: Optional[float] = None
    fiber_g: Optional[float] = None
    sugar_g: Optional[float] = None
    sodium_mg: Optional[float] = None
    saturated_fat_g: Optional[float] = None
    allergen_flags: Optional[list[str]] = None
    ingredients_text: Optional[str] = None


class BarcodeLookupResponse(BaseModel):
    found: bool
    food_item: Optional[FoodItemResponse] = None
    source: Optional[str] = None  # cache, local_db, openfoodfacts, usda


class FoodSearchResponse(BaseModel):
    items: list[FoodItemResponse]
    total: int
    query: str
