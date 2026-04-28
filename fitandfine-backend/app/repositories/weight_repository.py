import uuid
from datetime import date, timedelta
from typing import Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.weight_log import WeightLog
from app.repositories.base import BaseRepository


class WeightRepository(BaseRepository[WeightLog]):
    def __init__(self, session: AsyncSession):
        super().__init__(WeightLog, session)

    async def get_by_date(self, user_id: uuid.UUID, log_date: date) -> Optional[WeightLog]:
        result = await self.session.execute(
            select(WeightLog).where(
                WeightLog.user_id == user_id,
                WeightLog.log_date == log_date,
            )
        )
        return result.scalar_one_or_none()

    async def get_history(
        self, user_id: uuid.UUID, days: int = 90
    ) -> list[WeightLog]:
        cutoff = date.today() - timedelta(days=days)
        result = await self.session.execute(
            select(WeightLog)
            .where(
                WeightLog.user_id == user_id,
                WeightLog.log_date >= cutoff,
            )
            .order_by(WeightLog.log_date.asc())
        )
        return list(result.scalars().all())

    async def get_latest(self, user_id: uuid.UUID) -> Optional[WeightLog]:
        result = await self.session.execute(
            select(WeightLog)
            .where(WeightLog.user_id == user_id)
            .order_by(WeightLog.log_date.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()
