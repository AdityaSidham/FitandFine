import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Text, Numeric, Index, text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class ScanHistory(Base):
    __tablename__ = "scan_history"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    image_s3_key: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    image_s3_bucket: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    scan_type: Mapped[str] = mapped_column(
        String(20), nullable=False
    )  # nutrition_label, barcode
    ocr_raw_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    ocr_confidence: Mapped[Optional[float]] = mapped_column(Numeric(5, 4), nullable=True)
    parsed_result: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    food_item_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("food_items.id", ondelete="SET NULL"),
        nullable=True,
    )
    processing_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="pending"
    )  # pending, processing, complete, failed
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    celery_task_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        default=datetime.utcnow, nullable=False
    )
    completed_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="scan_history")

    __table_args__ = (
        Index("ix_scan_history_user_id_created_at", "user_id", "created_at"),
        Index(
            "ix_scan_history_processing_status",
            "processing_status",
            postgresql_where=text("processing_status IN ('pending', 'processing')"),
        ),
    )

    def __repr__(self) -> str:
        return f"<ScanHistory id={self.id} user_id={self.user_id} status={self.processing_status}>"
