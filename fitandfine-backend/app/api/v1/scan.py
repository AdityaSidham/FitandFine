"""
Phase 2 — Scan API
==================
POST /scan/label         Upload nutrition label image → Gemini Vision → parsed nutrition
GET  /scan/barcode/{code} Barcode lookup via USDA / OpenFoodFacts
POST /scan/confirm        User confirms (and optionally edits) parsed nutrition → saved food item
GET  /scan/history        List this user's recent scans
"""
import uuid
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.dependencies import get_current_user_id, get_db
from app.models.food_item import FoodItem
from app.models.scan_history import ScanHistory
from app.repositories.food_repository import FoodRepository
from app.schemas.scan import (
    LabelScanResponse,
    BarcodeScanResponse,
    ConfirmScanRequest,
    ConfirmScanResponse,
    ScanHistoryItem,
)
from app.services.food_db_service import lookup_barcode_usda, lookup_barcode_openfoodfacts
from app.services.label_scan_service import LabelScanService

logger = logging.getLogger(__name__)
router = APIRouter()

ALLOWED_TYPES = {
    "image/jpeg", "image/jpg", "image/png",
    "image/heic", "image/heif", "image/webp",
}
MAX_IMAGE_MB = 10


# ---------------------------------------------------------------------------
# POST /scan/label
# ---------------------------------------------------------------------------

@router.post(
    "/label",
    response_model=LabelScanResponse,
    summary="Scan a nutrition label using Gemini Vision",
)
async def scan_nutrition_label(
    file: UploadFile = File(..., description="JPEG / PNG / HEIC photo of a nutrition label"),
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user_id),
    settings: Settings = Depends(get_settings),
):
    """
    Upload a photo of a nutrition label (or packaged food product).
    Gemini Vision extracts the nutrition facts and returns structured data.
    Call POST /scan/confirm afterwards to save the food item to the database.
    """
    # ── Validate file ────────────────────────────────────────────────────────
    content_type = (file.content_type or "").lower().split(";")[0].strip()
    if content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image type '{content_type}'. Use JPEG, PNG, or HEIC.",
        )

    image_bytes = await file.read()
    size_mb = len(image_bytes) / (1024 * 1024)
    if size_mb > MAX_IMAGE_MB:
        raise HTTPException(
            status_code=413,
            detail=f"Image too large ({size_mb:.1f} MB). Maximum is {MAX_IMAGE_MB} MB.",
        )

    # ── Create pending scan record ───────────────────────────────────────────
    scan = ScanHistory(
        user_id=user_id,
        scan_type="nutrition_label",
        processing_status="processing",
    )
    db.add(scan)
    await db.flush()
    scan_id = str(scan.id)

    # ── Call Gemini Vision ───────────────────────────────────────────────────
    try:
        service = LabelScanService(settings)
        result = await service.parse_nutrition_label(
            image_bytes=image_bytes,
            mime_type=content_type or "image/jpeg",
        )

        scan.parsed_result = result.food.model_dump()
        scan.ocr_confidence = result.confidence
        scan.processing_status = "complete"
        scan.completed_at = datetime.now(timezone.utc).replace(tzinfo=None)

        confidence_pct = int(result.confidence * 100)
        if result.confidence >= 0.90:
            msg = f"Nutrition label parsed with high confidence ({confidence_pct}%)."
        elif result.confidence >= 0.70:
            msg = f"Label parsed with moderate confidence ({confidence_pct}%). Please review."
        else:
            msg = f"Low confidence ({confidence_pct}%). The label may be unclear — please verify."

        return LabelScanResponse(
            scan_id=scan_id,
            food=result.food,
            confidence=result.confidence,
            message=msg,
        )

    except ValueError as exc:
        scan.processing_status = "failed"
        scan.error_message = str(exc)
        raise HTTPException(status_code=422, detail=str(exc))

    except RuntimeError as exc:
        scan.processing_status = "failed"
        scan.error_message = str(exc)
        err_str = str(exc).lower()
        logger.error("Label scan failed (user=%s): %s", user_id, exc)

        # Surface quota errors clearly so the developer knows to rotate keys
        if "quota" in err_str or "resource_exhausted" in err_str or "429" in err_str:
            raise HTTPException(
                status_code=429,
                detail=(
                    "Gemini API free-tier quota exhausted. "
                    "Get a fresh key at https://aistudio.google.com/app/apikey "
                    "and update GEMINI_API_KEY in your .env file. "
                    "Alternatively set GEMINI_MODEL=gemini-1.5-flash to use a separate quota pool."
                ),
            )

        raise HTTPException(
            status_code=503,
            detail="AI service temporarily unavailable. Please try again in a moment.",
        )


# ---------------------------------------------------------------------------
# GET /scan/barcode/{barcode}
# ---------------------------------------------------------------------------

@router.get(
    "/barcode/{barcode}",
    response_model=BarcodeScanResponse,
    summary="Look up a food item by barcode",
)
async def lookup_barcode(
    barcode: str,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user_id),
    settings: Settings = Depends(get_settings),
):
    """
    Look up a barcode (UPC / EAN / QR code number) in the food database.
    Checks local DB first, then USDA FoodData Central, then OpenFoodFacts.
    """
    repo = FoodRepository(db)

    # 1. Check local DB first
    existing = await repo.get_by_barcode(barcode)
    if existing:
        from app.schemas.food import FoodItemResponse
        food_resp = FoodItemResponse.model_validate(existing)
        _log_barcode_scan(db, user_id, barcode, found=True, food_item_id=existing.id)
        return BarcodeScanResponse(found=True, food_item=food_resp, source="local_db")

    # 2. Try USDA
    usda_data = await lookup_barcode_usda(barcode)
    if usda_data:
        food_item = await repo.upsert_from_external(
            source="usda",
            external_id=usda_data.get("external_id", barcode),
            **{k: v for k, v in usda_data.items() if k not in ("source", "external_id")},
        )
        from app.schemas.food import FoodItemResponse
        food_resp = FoodItemResponse.model_validate(food_item)
        _log_barcode_scan(db, user_id, barcode, found=True, food_item_id=food_item.id)
        return BarcodeScanResponse(found=True, food_item=food_resp, source="usda")

    # 3. Try OpenFoodFacts
    off_data = await lookup_barcode_openfoodfacts(barcode)
    if off_data:
        food_item = await repo.upsert_from_external(
            source="openfoodfacts",
            external_id=off_data.get("external_id", barcode),
            **{k: v for k, v in off_data.items() if k not in ("source", "external_id")},
        )
        from app.schemas.food import FoodItemResponse
        food_resp = FoodItemResponse.model_validate(food_item)
        _log_barcode_scan(db, user_id, barcode, found=True, food_item_id=food_item.id)
        return BarcodeScanResponse(found=True, food_item=food_resp, source="openfoodfacts")

    _log_barcode_scan(db, user_id, barcode, found=False)
    return BarcodeScanResponse(found=False, source=None)


def _log_barcode_scan(db, user_id, barcode: str, found: bool, food_item_id=None):
    scan = ScanHistory(
        user_id=user_id,
        scan_type="barcode",
        processing_status="complete",
        parsed_result={"barcode": barcode, "found": found},
        food_item_id=food_item_id,
        completed_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(scan)


# ---------------------------------------------------------------------------
# POST /scan/confirm
# ---------------------------------------------------------------------------

@router.post(
    "/confirm",
    response_model=ConfirmScanResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Save a confirmed (user-reviewed) scan as a food item",
)
async def confirm_scan(
    body: ConfirmScanRequest,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user_id),
):
    """
    After the user reviews and optionally edits the parsed nutrition data,
    call this endpoint to persist the food item. Returns the new food_item_id
    which can be used immediately in POST /logs/daily.
    """
    repo = FoodRepository(db)
    food_dict = body.food.model_dump(exclude_none=True)
    food_dict["source"] = "gemini_scan"
    food_dict["is_verified"] = False
    food_dict["confidence_score"] = 0.85

    food_item = await repo.create(**food_dict)

    # Link the scan record to the saved food item
    if body.scan_id:
        try:
            scan_uuid = uuid.UUID(body.scan_id)
            scan_result = await db.execute(
                select(ScanHistory).where(
                    ScanHistory.id == scan_uuid,
                    ScanHistory.user_id == user_id,
                )
            )
            scan = scan_result.scalar_one_or_none()
            if scan:
                scan.food_item_id = food_item.id
        except Exception:
            pass  # non-critical

    return ConfirmScanResponse(
        food_item_id=str(food_item.id),
        message="Food item saved. You can now add it to your log.",
    )


# ---------------------------------------------------------------------------
# GET /scan/history
# ---------------------------------------------------------------------------

@router.get(
    "/history",
    response_model=list[ScanHistoryItem],
    summary="List recent scans for the current user",
)
async def get_scan_history(
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user_id),
):
    result = await db.execute(
        select(ScanHistory)
        .where(ScanHistory.user_id == user_id)
        .order_by(desc(ScanHistory.created_at))
        .limit(limit)
    )
    scans = result.scalars().all()

    items = []
    for s in scans:
        food_name = None
        if s.parsed_result and isinstance(s.parsed_result, dict):
            food_name = s.parsed_result.get("name")
        items.append(
            ScanHistoryItem(
                scan_id=str(s.id),
                scan_type=s.scan_type,
                status=s.processing_status,
                confidence=float(s.ocr_confidence) if s.ocr_confidence else None,
                food_name=food_name,
                created_at=s.created_at.isoformat(),
            )
        )
    return items
