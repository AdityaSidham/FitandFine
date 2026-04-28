import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Integer, Index, text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class AIConversation(Base, TimestampMixin):
    __tablename__ = "ai_conversations"

    id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    agent_type: Mapped[str] = mapped_column(
        String(30), nullable=False
    )  # coach, food_parser, diet_analyzer, recommender, progress_evaluator
    session_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), nullable=False, default=uuid.uuid4
    )
    messages: Mapped[list] = mapped_column(JSONB, nullable=False, default=list)
    context_snapshot: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    tokens_input: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    tokens_output: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    model_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    trigger_type: Mapped[Optional[str]] = mapped_column(
        String(30), nullable=True
    )  # user_initiated, scheduled, event_triggered
    trigger_context: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="ai_conversations")

    __table_args__ = (
        Index("ix_ai_conversations_user_agent_created", "user_id", "agent_type", "created_at"),
        Index("ix_ai_conversations_session_id", "session_id"),
    )

    def __repr__(self) -> str:
        return f"<AIConversation id={self.id} user_id={self.user_id} agent={self.agent_type}>"
