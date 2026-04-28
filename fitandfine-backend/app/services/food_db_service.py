import hashlib
import json
from typing import Optional

import httpx

from app.config import get_settings

settings = get_settings()

USDA_BASE_URL = "https://api.nal.usda.gov/fdc/v1"
OPENFOODFACTS_BASE_URL = "https://world.openfoodfacts.org/api/v2"


def _normalize_usda_food(usda_data: dict) -> dict:
    """Map USDA FoodData Central response to FitandFine food_item fields.

    USDA returns nutrients in two different shapes depending on the endpoint:
    - /foods/search  → {nutrientName, value, unitName}   (no nested "nutrient" key)
    - /food/{fdcId}  → {nutrient: {name, id}, amount}   (nested "nutrient" object)
    This function handles both.
    """
    raw_nutrients = usda_data.get("foodNutrients", [])
    nutrients: dict[str, float] = {}
    for n in raw_nutrients:
        if "nutrient" in n:
            # individual-food-item format
            name = n["nutrient"].get("name", "")
            value = n.get("amount")
        else:
            # search-result format
            name = n.get("nutrientName", "")
            value = n.get("value")
        if name and value is not None:
            nutrients[name] = value

    def get_nutrient_value(name: str) -> Optional[float]:
        val = nutrients.get(name)
        return float(val) if val is not None else None

    return {
        "name": usda_data.get("description", ""),
        "brand": usda_data.get("brandOwner") or usda_data.get("brandName"),
        "source": "usda",
        "external_id": str(usda_data.get("fdcId", "")),
        "serving_size_g": usda_data.get("servingSize"),
        "serving_size_description": usda_data.get("servingSizeUnit"),
        "calories": get_nutrient_value("Energy"),
        "protein_g": get_nutrient_value("Protein"),
        "carbohydrates_g": get_nutrient_value("Carbohydrate, by difference"),
        "fat_g": get_nutrient_value("Total lipid (fat)"),
        "fiber_g": get_nutrient_value("Fiber, total dietary"),
        "sugar_g": get_nutrient_value("Sugars, total including NLEA"),
        "sodium_mg": get_nutrient_value("Sodium, Na"),
        "saturated_fat_g": get_nutrient_value("Fatty acids, total saturated"),
        "is_verified": True,
    }


def _normalize_off_product(off_data: dict) -> dict:
    """Map OpenFoodFacts product to FitandFine food_item fields."""
    product = off_data.get("product", off_data)
    nutriments = product.get("nutriments", {})

    def get_n(key: str) -> Optional[float]:
        val = nutriments.get(f"{key}_100g") or nutriments.get(key)
        return float(val) if val is not None else None

    return {
        "name": product.get("product_name", ""),
        "brand": product.get("brands"),
        "barcode": product.get("code"),
        "source": "openfoodfacts",
        "external_id": product.get("code"),
        "serving_size_description": product.get("serving_size"),
        "calories": get_n("energy-kcal") or (
            (get_n("energy") or 0) / 4.184 if get_n("energy") else None
        ),
        "protein_g": get_n("proteins"),
        "carbohydrates_g": get_n("carbohydrates"),
        "fat_g": get_n("fat"),
        "fiber_g": get_n("fiber"),
        "sugar_g": get_n("sugars"),
        "sodium_mg": (get_n("sodium") or 0) * 1000 if get_n("sodium") else None,
        "saturated_fat_g": get_n("saturated-fat"),
        "ingredients_text": product.get("ingredients_text_en") or product.get("ingredients_text"),
        "is_verified": False,
    }


async def lookup_barcode_usda(barcode: str) -> Optional[dict]:
    """Search USDA by barcode (GTIN/UPC)."""
    if not settings.usda_api_key:
        return None
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(
            f"{USDA_BASE_URL}/foods/search",
            params={
                "query": barcode,
                "dataType": "Branded",
                "api_key": settings.usda_api_key,
                "pageSize": 1,
            },
        )
        if response.status_code != 200:
            return None
        data = response.json()
        foods = data.get("foods", [])
        if not foods:
            return None
        return _normalize_usda_food(foods[0])


async def lookup_barcode_openfoodfacts(barcode: str) -> Optional[dict]:
    """Look up barcode on OpenFoodFacts (no API key needed)."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(
            f"{OPENFOODFACTS_BASE_URL}/product/{barcode}",
            headers={"User-Agent": "FitandFine/1.0 (contact@fitandfine.app)"},
        )
        if response.status_code != 200:
            return None
        data = response.json()
        if data.get("status") != 1:
            return None
        return _normalize_off_product(data)


async def search_usda_foods(query: str, limit: int = 20) -> list[dict]:
    """Full-text search on USDA FoodData Central."""
    if not settings.usda_api_key:
        return []
    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.get(
            f"{USDA_BASE_URL}/foods/search",
            params={
                "query": query,
                "api_key": settings.usda_api_key,
                "pageSize": limit,
            },
        )
        if response.status_code != 200:
            return []
        data = response.json()
        return [_normalize_usda_food(f) for f in data.get("foods", [])]


def hash_query(query: str) -> str:
    """Stable hash for cache keys."""
    return hashlib.md5(query.lower().strip().encode()).hexdigest()[:16]
