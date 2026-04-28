import uuid
from datetime import date, datetime
from typing import Optional

from sqlalchemy import String, Date, Numeric, ARRAY, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[Optional[str]] = mapped_column(String(255), unique=True, nullable=True)
    apple_user_id: Mapped[Optional[str]] = mapped_column(String(255), unique=True, nullable=True)
    google_user_id: Mapped[Optional[str]] = mapped_column(String(255), unique=True, nullable=True)
    display_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    date_of_birth: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    sex: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)  # male, female, other
    height_cm: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    activity_level: Mapped[Optional[str]] = mapped_column(
        String(30), nullable=True
    )  # sedentary, light, moderate, active, very_active
    timezone: Mapped[str] = mapped_column(String(50), default="UTC", nullable=False)
    dietary_restrictions: Mapped[Optional[list]] = mapped_column(ARRAY(String), nullable=True)
    allergies: Mapped[Optional[list]] = mapped_column(ARRAY(String), nullable=True)
    preferred_cuisine: Mapped[Optional[list]] = mapped_column(ARRAY(String), nullable=True)
    budget_per_meal_usd: Mapped[Optional[float]] = mapped_column(Numeric(6, 2), nullable=True)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)

    # Relationships
    goals: Mapped[list["UserGoal"]] = relationship("UserGoal", back_populates="user", lazy="select")
    daily_logs: Mapped[list["DailyLog"]] = relationship("DailyLog", back_populates="user", lazy="select")
    weight_logs: Mapped[list["WeightLog"]] = relationship("WeightLog", back_populates="user", lazy="select")
    ai_conversations: Mapped[list["AIConversation"]] = relationship("AIConversation", back_populates="user", lazy="select")
    scan_history: Mapped[list["ScanHistory"]] = relationship("ScanHistory", back_populates="user", lazy="select")

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email}>"
