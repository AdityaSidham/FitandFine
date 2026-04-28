import uuid
from datetime import date, datetime
from typing import Optional

from sqlalchemy import String, Date, Numeric, Boolean, Integer, Index, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class UserGoal(Base, TimestampMixin):
    __tablename__ = "user_goals"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    goal_type: Mapped[str] = mapped_column(
        String(30), nullable=False
    )  # lose_weight, maintain, gain_muscle, recomp
    target_weight_kg: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    target_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    calorie_target: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    protein_pct: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    carb_pct: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    fat_pct: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    protein_g: Mapped[Optional[float]] = mapped_column(Numeric(6, 2), nullable=True)
    carb_g: Mapped[Optional[float]] = mapped_column(Numeric(6, 2), nullable=True)
    fat_g: Mapped[Optional[float]] = mapped_column(Numeric(6, 2), nullable=True)
    weekly_weight_change_target_kg: Mapped[Optional[float]] = mapped_column(
        Numeric(4, 2), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="goals")

    __table_args__ = (
        Index("ix_user_goals_user_id_active", "user_id", "is_active"),
    )

    def __repr__(self) -> str:
        return f"<UserGoal id={self.id} user_id={self.user_id} type={self.goal_type}>"
