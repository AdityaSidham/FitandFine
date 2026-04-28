import uuid
from typing import Optional

from sqlalchemy import select, or_, func, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.food_item import FoodItem
from app.repositories.base import BaseRepository


class FoodRepository(BaseRepository[FoodItem]):
    def __init__(self, session: AsyncSession):
        super().__init__(FoodItem, session)

    async def get_by_barcode(self, barcode: str) -> Optional[FoodItem]:
        result = await self.session.execute(
            select(FoodItem).where(FoodItem.barcode == barcode)
        )
        return result.scalar_one_or_none()

    async def get_by_external_id(self, source: str, external_id: str) -> Optional[FoodItem]:
        result = await self.session.execute(
            select(FoodItem).where(
                FoodItem.source == source,
                FoodItem.external_id == external_id,
            )
        )
        return result.scalar_one_or_none()

    async def search_by_name(
        self, query: str, limit: int = 20, offset: int = 0
    ) -> tuple[list[FoodItem], int]:
        """Full-text search on name + brand using PostgreSQL tsvector."""
        ts_query = func.plainto_tsquery("english", query)
        ts_vector = func.to_tsvector(
            "english",
            func.coalesce(FoodItem.name, "") + " " + func.coalesce(FoodItem.brand, ""),
        )
        stmt = (
            select(FoodItem)
            .where(ts_vector.op("@@")(ts_query))
            .order_by(func.ts_rank(ts_vector, ts_query).desc())
            .limit(limit)
            .offset(offset)
        )
        count_stmt = select(func.count()).select_from(
            select(FoodItem).where(ts_vector.op("@@")(ts_query)).subquery()
        )
        result = await self.session.execute(stmt)
        count_result = await self.session.execute(count_stmt)
        items = list(result.scalars().all())
        total = count_result.scalar_one()
        return items, total

    async def upsert_from_external(
        self, source: str, external_id: str, **kwargs
    ) -> FoodItem:
        existing = await self.get_by_external_id(source, external_id)
        if existing:
            return await self.update(existing, **kwargs)
        return await self.create(source=source, external_id=external_id, **kwargs)
