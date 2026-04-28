import uuid
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    def __init__(self, session: AsyncSession):
        super().__init__(User, session)

    async def get_by_email(self, email: str) -> Optional[User]:
        result = await self.session.execute(
            select(User).where(User.email == email, User.deleted_at.is_(None))
        )
        return result.scalar_one_or_none()

    async def get_by_apple_id(self, apple_user_id: str) -> Optional[User]:
        result = await self.session.execute(
            select(User).where(User.apple_user_id == apple_user_id, User.deleted_at.is_(None))
        )
        return result.scalar_one_or_none()

    async def get_by_google_id(self, google_user_id: str) -> Optional[User]:
        result = await self.session.execute(
            select(User).where(User.google_user_id == google_user_id, User.deleted_at.is_(None))
        )
        return result.scalar_one_or_none()

    async def get_active_by_id(self, user_id: uuid.UUID) -> Optional[User]:
        result = await self.session.execute(
            select(User).where(User.id == user_id, User.deleted_at.is_(None))
        )
        return result.scalar_one_or_none()

    async def soft_delete(self, user: User) -> User:
        from datetime import datetime, timezone
        return await self.update(user, deleted_at=datetime.now(timezone.utc))
