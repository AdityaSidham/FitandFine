import uuid
from datetime import date
from typing import Optional

from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_log import DailyLog
from app.repositories.base import BaseRepository


class LogRepository(BaseRepository[DailyLog]):
    def __init__(self, session: AsyncSession):
        super().__init__(DailyLog, session)

    async def get_daily_logs(
        self, user_id: uuid.UUID, log_date: date
    ) -> list[DailyLog]:
        result = await self.session.execute(
            select(DailyLog)
            .where(
                DailyLog.user_id == user_id,
                DailyLog.log_date == log_date,
                DailyLog.deleted_at.is_(None),
            )
            .order_by(DailyLog.log_time)
        )
        return list(result.scalars().all())

    async def get_daily_totals(
        self, user_id: uuid.UUID, log_date: date
    ) -> dict:
        result = await self.session.execute(
            select(
                func.coalesce(func.sum(DailyLog.calories_consumed), 0).label("calories"),
                func.coalesce(func.sum(DailyLog.protein_consumed_g), 0).label("protein_g"),
                func.coalesce(func.sum(DailyLog.carbs_consumed_g), 0).label("carbs_g"),
                func.coalesce(func.sum(DailyLog.fat_consumed_g), 0).label("fat_g"),
                func.count(DailyLog.id).label("entries_count"),
            ).where(
                DailyLog.user_id == user_id,
                DailyLog.log_date == log_date,
                DailyLog.deleted_at.is_(None),
            )
        )
        row = result.one()
        return {
            "calories": float(row.calories),
            "protein_g": float(row.protein_g),
            "carbs_g": float(row.carbs_g),
            "fat_g": float(row.fat_g),
            "entries_count": row.entries_count,
        }

    async def soft_delete(self, log: DailyLog) -> DailyLog:
        from datetime import datetime, timezone
        # Use naive UTC — columns are TIMESTAMP WITHOUT TIME ZONE
        return await self.update(log, deleted_at=datetime.now(timezone.utc).replace(tzinfo=None))

    async def get_by_id_for_user(
        self, log_id: uuid.UUID, user_id: uuid.UUID
    ) -> Optional[DailyLog]:
        result = await self.session.execute(
            select(DailyLog).where(
                DailyLog.id == log_id,
                DailyLog.user_id == user_id,
                DailyLog.deleted_at.is_(None),
            )
        )
        return result.scalar_one_or_none()

    async def get_range_daily_totals(
        self, user_id: uuid.UUID, start_date: date, end_date: date
    ) -> list[dict]:
        """Return per-day macro totals for a date range, ordered by date."""
        result = await self.session.execute(
            select(
                DailyLog.log_date,
                func.coalesce(func.sum(DailyLog.calories_consumed), 0).label("calories"),
                func.coalesce(func.sum(DailyLog.protein_consumed_g), 0).label("protein_g"),
                func.coalesce(func.sum(DailyLog.carbs_consumed_g), 0).label("carbs_g"),
                func.coalesce(func.sum(DailyLog.fat_consumed_g), 0).label("fat_g"),
                func.count(DailyLog.id).label("entries_count"),
            ).where(
                DailyLog.user_id == user_id,
                DailyLog.log_date >= start_date,
                DailyLog.log_date <= end_date,
                DailyLog.deleted_at.is_(None),
            )
            .group_by(DailyLog.log_date)
            .order_by(DailyLog.log_date)
        )
        return [
            {
                "date": str(row.log_date),
                "calories": float(row.calories),
                "protein_g": float(row.protein_g),
                "carbs_g": float(row.carbs_g),
                "fat_g": float(row.fat_g),
                "entries_count": row.entries_count,
            }
            for row in result.all()
        ]
