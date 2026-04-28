import uuid
from datetime import date, datetime
from typing import Optional

from sqlalchemy import String, Numeric, Date, Index, Text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class DailyLog(Base):
    __tablename__ = "daily_logs"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    food_item_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("food_items.id", ondelete="RESTRICT"),
        nullable=False,
    )
    log_date: Mapped[date] = mapped_column(Date, nullable=False)
    log_time: Mapped[datetime] = mapped_column(nullable=False)
    meal_type: Mapped[str] = mapped_column(
        String(20), nullable=False
    )  # breakfast, lunch, dinner, snack, drink
    quantity: Mapped[float] = mapped_column(Numeric(10, 3), nullable=False)
    serving_description: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    # Denormalized for fast reads
    calories_consumed: Mapped[float] = mapped_column(Numeric(8, 2), nullable=False)
    protein_consumed_g: Mapped[float] = mapped_column(Numeric(8, 3), nullable=False)
    carbs_consumed_g: Mapped[float] = mapped_column(Numeric(8, 3), nullable=False)
    fat_consumed_g: Mapped[float] = mapped_column(Numeric(8, 3), nullable=False)
    entry_method: Mapped[Optional[str]] = mapped_column(
        String(30), nullable=True
    )  # barcode, ocr_scan, manual, ai_suggested
    scan_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PG_UUID(as_uuid=True), nullable=True
    )
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        default=datetime.utcnow, nullable=False
    )
    deleted_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="daily_logs")
    food_item: Mapped["FoodItem"] = relationship("FoodItem")

    __table_args__ = (
        Index("ix_daily_logs_user_id_log_date", "user_id", "log_date"),
        Index("ix_daily_logs_user_id_log_time", "user_id", "log_time"),
    )

    def __repr__(self) -> str:
        return f"<DailyLog id={self.id} user_id={self.user_id} date={self.log_date}>"
