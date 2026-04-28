"""
Phase 2 — OCR Celery Tasks
===========================
These tasks handle async re-processing of scans (retries, batch jobs).
The primary scan path is synchronous via LabelScanService (< 3s via Gemini Vision).
Celery tasks are used for:
  - Retrying failed scans
  - Batch-processing historical scans
  - Future: offline Tesseract fallback when Gemini is unavailable
"""
import logging
import uuid
from datetime import datetime, timezone

from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(
    bind=True,
    max_retries=3,
    default_retry_delay=10,
    queue="ocr",
    name="app.tasks.ocr_tasks.process_label_scan",
)
def process_label_scan(self, scan_id: str) -> dict:
    """
    Re-process a failed or pending nutrition label scan.

    Flow:
    1. Load ScanHistory record from DB
    2. Download image from S3 (if stored)
    3. Call LabelScanService.parse_nutrition_label
    4. Update scan record with results
    5. Create FoodItem if confidence > 0.85

    This runs in a separate Celery worker process — use sync DB access
    via SQLAlchemy sync engine, not asyncpg.
    """
    from app.config import get_settings
    settings = get_settings()

    # Import here to avoid circular imports at module load time
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session
    from app.models.scan_history import ScanHistory
    from app.models.food_item import FoodItem

    engine = create_engine(settings.sync_database_url, pool_pre_ping=True)

    with Session(engine) as session:
        scan = session.get(ScanHistory, uuid.UUID(scan_id))
        if not scan:
            logger.warning("Scan %s not found, skipping", scan_id)
            return {"status": "not_found", "scan_id": scan_id}

        if scan.processing_status == "complete":
            return {"status": "already_complete", "scan_id": scan_id}

        scan.processing_status = "processing"
        scan.celery_task_id = self.request.id
        session.commit()

        # Phase 2: if image is stored in S3, download and re-process
        if scan.image_s3_key and scan.image_s3_bucket:
            try:
                import boto3
                s3 = boto3.client("s3")
                obj = s3.get_object(Bucket=scan.image_s3_bucket, Key=scan.image_s3_key)
                image_bytes = obj["Body"].read()

                # Sync wrapper around the async service
                import asyncio
                from app.services.label_scan_service import LabelScanService
                service = LabelScanService(settings)
                result = asyncio.run(service.parse_nutrition_label(image_bytes))

                scan.parsed_result = result.food.model_dump()
                scan.ocr_confidence = result.confidence
                scan.processing_status = "complete"
                scan.completed_at = datetime.now(timezone.utc).replace(tzinfo=None)

                # Auto-save food item if high confidence
                if result.confidence >= 0.85 and scan.food_item_id is None:
                    food_data = result.food.model_dump(exclude_none=True)
                    food_data.update({"source": "gemini_scan", "is_verified": False,
                                      "confidence_score": result.confidence})
                    food_item = FoodItem(**food_data)
                    session.add(food_item)
                    session.flush()
                    scan.food_item_id = food_item.id

                session.commit()
                return {"status": "complete", "scan_id": scan_id, "confidence": result.confidence}

            except Exception as exc:
                logger.error("OCR task failed for scan %s: %s", scan_id, exc)
                scan.processing_status = "failed"
                scan.error_message = str(exc)
                session.commit()
                raise self.retry(exc=exc)
        else:
            # No image stored — mark as failed (synchronous path is preferred)
            scan.processing_status = "failed"
            scan.error_message = "No image stored for re-processing"
            session.commit()
            return {"status": "no_image", "scan_id": scan_id}
