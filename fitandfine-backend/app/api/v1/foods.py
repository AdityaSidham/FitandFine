"""
Foods router — barcode lookup, full-text search, manual entry, food by ID,
and Phase-2 label-scan stubs.
"""
import json
import logging
import uuid
from typing import Annotated, Optional

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user_id, get_db, get_redis
from app.repositories.food_repository import FoodRepository
from app.schemas.food import (
    BarcodeLookupResponse,
    FoodItemCreate,
    FoodItemResponse,
    FoodSearchResponse,
)
from app.services.cache_service import CacheService
from app.services.food_db_service import (
    hash_query,
    lookup_barcode_openfoodfacts,
    lookup_barcode_usda,
    search_usda_foods,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ---------------------------------------------------------------------------
# Helper — convert external food dict to FoodItem kwargs
# ---------------------------------------------------------------------------

def _external_to_kwargs(data: dict) -> dict:
    """Normalize an external API food dict to FoodItem column kwargs."""
    return {
        "name": data.get("name", "Unknown"),
        "brand": data.get("brand"),
        "barcode": data.get("barcode"),
        "barcode_type": data.get("barcode_type"),
        "serving_size_g": data.get("serving_size_g"),
        "serving_size_description": data.get("serving_size_description"),
        "calories": data.get("calories"),
        "protein_g": data.get("protein_g"),
        "carbohydrates_g": data.get("carbohydrates_g"),
        "fat_g": data.get("fat_g"),
        "fiber_g": data.get("fiber_g"),
        "sugar_g": data.get("sugar_g"),
        "sodium_mg": data.get("sodium_mg"),
        "cholesterol_mg": data.get("cholesterol_mg"),
        "saturated_fat_g": data.get("saturated_fat_g"),
        "trans_fat_g": data.get("trans_fat_g"),
        "vitamins": data.get("vitamins"),
        "minerals": data.get("minerals"),
        "ingredients_text": data.get("ingredients_text"),
        "allergen_flags": data.get("allergen_flags"),
        "confidence_score": data.get("confidence_score"),
        "is_verified": data.get("is_verified", False),
    }


# ---------------------------------------------------------------------------
# GET /barcode/{barcode}
# ---------------------------------------------------------------------------

@router.get(
    "/barcode/{barcode}",
    response_model=BarcodeLookupResponse,
    status_code=status.HTTP_200_OK,
    summary="Look up a food item by barcode",
)
async def lookup_barcode(
    barcode: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
) -> BarcodeLookupResponse:
    """
    Lookup order:
    1. Redis cache
    2. Local DB
    3. Open Food Facts
    4. USDA FoodData Central
    """
    cache = CacheService(redis)

    # 1. Redis cache hit
    cached = await cache.get_food_by_barcode(barcode)
    if cached is not None:
        try:
            item_data = json.loads(cached) if isinstance(cached, str) else cached
            food_response = FoodItemResponse.model_validate(item_data)
            return BarcodeLookupResponse(found=True, food_item=food_response, source="cache")
        except Exception:
            pass  # Cache parse error — fall through to DB

    # 2. Local DB
    repo = FoodRepository(db)
    food_item = await repo.get_by_barcode(barcode)
    if food_item is not None:
        food_response = FoodItemResponse.model_validate(food_item, from_attributes=True)
        await cache.set_food_by_barcode(barcode, food_response.model_dump(mode="json"))
        return BarcodeLookupResponse(found=True, food_item=food_response, source="local_db")

    # 3. Open Food Facts
    try:
        off_data = await lookup_barcode_openfoodfacts(barcode)
    except Exception as exc:
        logger.warning("OpenFoodFacts lookup failed for %s: %s", barcode, exc)
        off_data = None

    if off_data:
        external_id = off_data.get("external_id") or barcode
        kwargs = _external_to_kwargs(off_data)
        kwargs["barcode"] = barcode
        food_item = await repo.upsert_from_external(
            source="openfoodfacts", external_id=external_id, **kwargs
        )
        food_response = FoodItemResponse.model_validate(food_item, from_attributes=True)
        await cache.set_food_by_barcode(barcode, food_response.model_dump(mode="json"))
        return BarcodeLookupResponse(
            found=True, food_item=food_response, source="openfoodfacts"
        )

    # 4. USDA FoodData Central
    try:
        usda_data = await lookup_barcode_usda(barcode)
    except Exception as exc:
        logger.warning("USDA barcode lookup failed for %s: %s", barcode, exc)
        usda_data = None

    if usda_data:
        external_id = usda_data.get("external_id") or barcode
        kwargs = _external_to_kwargs(usda_data)
        kwargs["barcode"] = barcode
        food_item = await repo.upsert_from_external(
            source="usda", external_id=external_id, **kwargs
        )
        food_response = FoodItemResponse.model_validate(food_item, from_attributes=True)
        await cache.set_food_by_barcode(barcode, food_response.model_dump(mode="json"))
        return BarcodeLookupResponse(found=True, food_item=food_response, source="usda")

    return BarcodeLookupResponse(found=False, food_item=None, source=None)


# ---------------------------------------------------------------------------
# GET /search
# ---------------------------------------------------------------------------

@router.get(
    "/search",
    response_model=FoodSearchResponse,
    status_code=status.HTTP_200_OK,
    summary="Full-text food search",
)
async def search_foods(
    db: Annotated[AsyncSession, Depends(get_db)],
    redis: Annotated[aioredis.Redis, Depends(get_redis)],
    q: Annotated[str, Query(min_length=1, description="Search query")],
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> FoodSearchResponse:
    """
    Full-text search across local DB; augmented with USDA results when
    local results are sparse (< 5 items).
    """
    cache = CacheService(redis)
    cache_key = hash_query(f"{q}:{limit}")

    # 1. Check Redis cache
    cached_raw = await cache.get_food_search(cache_key)
    if cached_raw is not None:
        try:
            items_data = json.loads(cached_raw) if isinstance(cached_raw, str) else cached_raw
            items = [FoodItemResponse.model_validate(i) for i in items_data]
            return FoodSearchResponse(items=items, total=len(items), query=q)
        except Exception:
            pass

    # 2. Local DB search
    repo = FoodRepository(db)
    local_items, _total = await repo.search_by_name(query=q, limit=limit)

    # 3. Augment with USDA if local results are thin
    all_items = list(local_items)
    if len(local_items) < 5:
        try:
            usda_results = await search_usda_foods(query=q, limit=limit)
        except Exception as exc:
            logger.warning("USDA search failed for '%s': %s", q, exc)
            usda_results = []

        if usda_results:
            existing_external_ids = {
                item.external_id for item in local_items if item.external_id
            }
            for usda_item in usda_results:
                ext_id = usda_item.get("external_id")
                if ext_id and ext_id in existing_external_ids:
                    continue  # Already in local results
                kwargs = _external_to_kwargs(usda_item)
                try:
                    saved = await repo.upsert_from_external(
                        source="usda",
                        external_id=ext_id or str(uuid.uuid4()),
                        **kwargs,
                    )
                    all_items.append(saved)
                    if ext_id:
                        existing_external_ids.add(ext_id)
                except Exception as exc:
                    logger.warning("Failed to upsert USDA item: %s", exc)

    # Respect the limit after merge
    all_items = all_items[:limit]

    # 4. Cache the merged results
    responses = [FoodItemResponse.model_validate(i, from_attributes=True) for i in all_items]
    try:
        await cache.set_food_search(
            cache_key, [r.model_dump(mode="json") for r in responses]
        )
    except Exception as exc:
        logger.warning("Failed to cache search results: %s", exc)

    return FoodSearchResponse(items=responses, total=len(responses), query=q)


# ---------------------------------------------------------------------------
# POST /manual
# ---------------------------------------------------------------------------

@router.post(
    "/manual",
    response_model=FoodItemResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a custom food item",
)
async def create_manual_food(
    body: FoodItemCreate,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> FoodItemResponse:
    """Create a user-defined food entry (source='manual')."""
    repo = FoodRepository(db)
    food_item = await repo.create(
        **body.model_dump(exclude_none=True),
        source="manual",
        created_by_user_id=user_id,
        is_verified=False,
    )
    return FoodItemResponse.model_validate(food_item, from_attributes=True)


# ---------------------------------------------------------------------------
# GET /{food_id}
# ---------------------------------------------------------------------------

@router.get(
    "/{food_id}",
    response_model=FoodItemResponse,
    status_code=status.HTTP_200_OK,
    summary="Get food item by ID",
)
async def get_food_by_id(
    food_id: uuid.UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> FoodItemResponse:
    """Fetch a single food item by its UUID."""
    repo = FoodRepository(db)
    food_item = await repo.get_by_id(food_id)
    if food_item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Food item {food_id} not found",
        )
    return FoodItemResponse.model_validate(food_item, from_attributes=True)


# ---------------------------------------------------------------------------
# POST /label-scan  (Phase 2 stub)
# ---------------------------------------------------------------------------

@router.post(
    "/label-scan",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Initiate nutrition label OCR scan (Phase 2)",
)
async def initiate_label_scan(
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
) -> dict:
    """Phase 2 stub — OCR pipeline not yet implemented."""
    scan_id = str(uuid.uuid4())
    return {
        "scan_id": scan_id,
        "status": "pending",
        "message": "OCR scanning available in Phase 2",
    }


# ---------------------------------------------------------------------------
# GET /label-scan/{scan_id}  (Phase 2 stub)
# ---------------------------------------------------------------------------

@router.get(
    "/label-scan/{scan_id}",
    status_code=status.HTTP_200_OK,
    summary="Get label scan status (Phase 2)",
)
async def get_label_scan(
    scan_id: str,
    user_id: Annotated[uuid.UUID, Depends(get_current_user_id)],
) -> dict:
    """Phase 2 stub — returns pending status for any scan ID."""
    return {
        "scan_id": scan_id,
        "status": "pending",
        "message": "OCR scanning available in Phase 2",
    }
