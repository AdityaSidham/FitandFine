import uuid
from datetime import date, datetime
from typing import Optional

from sqlalchemy import String, Numeric, Date, Text, UniqueConstraint, Index, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class WeightLog(Base):
    __tablename__ = "weight_logs"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    log_date: Mapped[date] = mapped_column(Date, nullable=False)
    log_time: Mapped[datetime] = mapped_column(nullable=False)
    weight_kg: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False)
    body_fat_pct: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    muscle_mass_kg: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    water_pct: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    measurement_source: Mapped[Optional[str]] = mapped_column(
        String(30), nullable=True
    )  # manual, apple_health, smart_scale
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        default=datetime.utcnow, nullable=False
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="weight_logs")

    __table_args__ = (
        UniqueConstraint("user_id", "log_date", name="uq_weight_logs_user_date"),
        Index("ix_weight_logs_user_id_log_date", "user_id", "log_date"),
    )

    def __repr__(self) -> str:
        return f"<WeightLog id={self.id} user_id={self.user_id} weight={self.weight_kg}>"
