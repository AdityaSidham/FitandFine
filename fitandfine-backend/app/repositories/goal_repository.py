import uuid
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_goal import UserGoal
from app.repositories.base import BaseRepository


class GoalRepository(BaseRepository[UserGoal]):
    def __init__(self, session: AsyncSession):
        super().__init__(UserGoal, session)

    async def get_active_goal(self, user_id: uuid.UUID) -> Optional[UserGoal]:
        result = await self.session.execute(
            select(UserGoal).where(
                UserGoal.user_id == user_id,
                UserGoal.is_active == True,
            )
        )
        return result.scalar_one_or_none()

    async def deactivate_all_goals(self, user_id: uuid.UUID) -> None:
        result = await self.session.execute(
            select(UserGoal).where(
                UserGoal.user_id == user_id,
                UserGoal.is_active == True,
            )
        )
        goals = result.scalars().all()
        for goal in goals:
            goal.is_active = False
            self.session.add(goal)
        await self.session.flush()

    async def get_goal_history(
        self, user_id: uuid.UUID, limit: int = 10
    ) -> list[UserGoal]:
        result = await self.session.execute(
            select(UserGoal)
            .where(UserGoal.user_id == user_id)
            .order_by(UserGoal.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())
