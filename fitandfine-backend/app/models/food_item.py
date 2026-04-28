import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Numeric, Boolean, Text, ARRAY, Index, text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class FoodItem(Base, TimestampMixin):
    __tablename__ = "food_items"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    brand: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    barcode: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    barcode_type: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    source: Mapped[str] = mapped_column(
        String(30), nullable=False
    )  # usda, openfoodfacts, user_scanned, manual
    external_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    serving_size_g: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    serving_size_description: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    calories: Mapped[Optional[float]] = mapped_column(Numeric(8, 2), nullable=True)
    protein_g: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    carbohydrates_g: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    fat_g: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    fiber_g: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    sugar_g: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    sodium_mg: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    cholesterol_mg: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    saturated_fat_g: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    trans_fat_g: Mapped[Optional[float]] = mapped_column(Numeric(8, 3), nullable=True)
    vitamins: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    minerals: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    ingredients_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    allergen_flags: Mapped[Optional[list]] = mapped_column(ARRAY(String), nullable=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    confidence_score: Mapped[Optional[float]] = mapped_column(Numeric(3, 2), nullable=True)
    created_by_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PG_UUID(as_uuid=True), nullable=True
    )

    __table_args__ = (
        Index(
            "ix_food_items_barcode",
            "barcode",
            postgresql_where=text("barcode IS NOT NULL"),
        ),
        Index(
            "ix_food_items_source_external",
            "source",
            "external_id",
            postgresql_where=text("external_id IS NOT NULL"),
        ),
        # Full-text search index created in migration as a functional index
    )

    def __repr__(self) -> str:
        return f"<FoodItem id={self.id} name={self.name}>"
