"""
Phase 3 — AI Coach Service
===========================
Stateful, multi-turn nutrition coach powered by Gemini.
Streams responses as SSE chunks.

Conversation history is persisted in ai_conversations (JSONB messages field).
Each user has one "active" coach session; starting a new session archives the old one.
"""
import asyncio
import json
import logging
import queue as sync_queue
import uuid
from datetime import date, timedelta
from typing import AsyncGenerator, Optional

import google.generativeai as genai
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.models.ai_conversation import AIConversation
from app.models.daily_log import DailyLog
from app.models.food_item import FoodItem
from app.models.user import User
from app.models.user_goal import UserGoal

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# System prompt
# ---------------------------------------------------------------------------

_COACH_SYSTEM = """\
You are FitCoach, a friendly and knowledgeable AI nutrition coach inside the FitandFine app.
You have access to the user's recent food logs, calorie targets, and macro goals — this context \
is provided at the start of every conversation.

Your personality:
- Warm, encouraging, and direct — not preachy or medical
- Evidence-based: cite mechanisms briefly (e.g. "protein helps preserve muscle during a deficit")
- Practical: suggest real foods and actionable tweaks, not vague advice
- Concise: 2–4 sentences per point, no bullet lists unless the user asks for them

What you can help with:
- Why am I not losing / gaining weight?
- What should I eat to hit my protein goal?
- Is my diet on track this week?
- Meal ideas that fit my remaining macros
- How to improve adherence / reduce cravings

Strict rules:
- Never diagnose or treat medical conditions
- Never recommend supplements beyond whole foods
- If calorie target would drop below 1200 kcal (women) or 1500 kcal (men), flag it as potentially unsafe
- If you don't have enough data to answer, say so honestly
"""


class CoachService:
    """Streaming AI coach using Gemini multi-turn chat."""

    def __init__(self, settings: Settings):
        self.settings = settings
        if settings.gemini_api_key:
            genai.configure(api_key=settings.gemini_api_key)

    # ------------------------------------------------------------------
    # Public — stream SSE chunks
    # ------------------------------------------------------------------

    async def stream_response(
        self,
        user_id: str,
        message: str,
        db: AsyncSession,
        session_id: Optional[str] = None,
    ) -> AsyncGenerator[str, None]:
        """
        Yields SSE-formatted strings:  data: {"text": "...", "done": false}\n\n
        Final chunk:                   data: {"text": "", "done": true}\n\n
        """
        if not self.settings.gemini_api_key:
            yield _sse({"error": "GEMINI_API_KEY not configured", "done": True})
            return

        # ── Load or create conversation ──────────────────────────────────
        conv = await self._load_or_create_conversation(
            db=db, user_id=user_id, session_id=session_id
        )
        history = conv.messages or []

        # ── Build context block (injected as first user message if fresh) ─
        if not history:
            context = await self._build_context(db=db, user_id=user_id)
            history = [
                {"role": "user",  "parts": [context]},
                {"role": "model", "parts": ["Understood! I have your nutrition data loaded. What would you like to know?"]},
            ]

        # ── Add user message ─────────────────────────────────────────────
        history.append({"role": "user", "parts": [message]})

        # ── Stream Gemini response ───────────────────────────────────────
        full_reply = ""
        try:
            async for chunk_text in self._gemini_stream(history):
                full_reply += chunk_text
                yield _sse({"text": chunk_text, "done": False})
        except Exception as exc:
            logger.error("Coach stream error (user=%s): %s", user_id, exc)
            yield _sse({"error": str(exc), "done": True})
            return

        # ── Persist updated history ──────────────────────────────────────
        history.append({"role": "model", "parts": [full_reply]})
        conv.messages = history
        await db.commit()

        yield _sse({"text": "", "done": True})

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    async def _load_or_create_conversation(
        self,
        db: AsyncSession,
        user_id: str,
        session_id: Optional[str],
    ) -> AIConversation:
        """Load existing active session or create a new one."""
        if session_id:
            try:
                sid = uuid.UUID(session_id)
                result = await db.execute(
                    select(AIConversation).where(
                        AIConversation.session_id == sid,
                        AIConversation.user_id == uuid.UUID(user_id),
                        AIConversation.agent_type == "coach",
                    )
                )
                conv = result.scalar_one_or_none()
                if conv:
                    return conv
            except Exception:
                pass

        # Create new session
        conv = AIConversation(
            user_id=uuid.UUID(user_id),
            agent_type="coach",
            session_id=uuid.uuid4(),
            messages=[],
            trigger_type="user_initiated",
            model_version=self.settings.gemini_model,
        )
        db.add(conv)
        await db.flush()
        return conv

    async def _build_context(self, db: AsyncSession, user_id: str) -> str:
        """Build a context string with user profile, goal, and recent food logs."""
        uid = uuid.UUID(user_id)
        today = date.today()
        week_ago = today - timedelta(days=7)

        # User profile
        user_result = await db.execute(select(User).where(User.id == uid))
        user = user_result.scalar_one_or_none()

        # Active goal
        goal_result = await db.execute(
            select(UserGoal)
            .where(UserGoal.user_id == uid, UserGoal.is_active == True)
            .limit(1)
        )
        goal = goal_result.scalar_one_or_none()

        # Last 7 days logs
        logs_result = await db.execute(
            select(DailyLog, FoodItem)
            .join(FoodItem, DailyLog.food_item_id == FoodItem.id)
            .where(
                DailyLog.user_id == uid,
                DailyLog.log_date >= week_ago,
                DailyLog.deleted_at.is_(None),
            )
            .order_by(DailyLog.log_date)
        )
        log_rows = logs_result.all()

        # Aggregate by day
        daily: dict[str, dict] = {}
        for log, food in log_rows:
            key = str(log.log_date)
            if key not in daily:
                daily[key] = {"calories": 0, "protein": 0, "carbs": 0, "fat": 0, "foods": []}
            daily[key]["calories"] += float(log.calories_consumed or 0)
            daily[key]["protein"]  += float(log.protein_consumed_g or 0)
            daily[key]["carbs"]    += float(log.carbs_consumed_g or 0)
            daily[key]["fat"]      += float(log.fat_consumed_g or 0)
            daily[key]["foods"].append(food.name)

        # Format context
        lines = ["=== USER CONTEXT (do not repeat this to the user) ==="]

        if user:
            lines.append(f"Display name: {user.display_name or 'User'}")
            if user.sex:
                lines.append(f"Sex: {user.sex}")

        if goal:
            lines.append(f"\nActive goal: {goal.goal_type.replace('_', ' ').title()}")
            if goal.calorie_target:
                lines.append(f"Daily calorie target: {goal.calorie_target} kcal")
            if goal.protein_g:
                lines.append(f"Protein target: {goal.protein_g:.0f}g")
            if goal.carb_g:
                lines.append(f"Carb target: {goal.carb_g:.0f}g")
            if goal.fat_g:
                lines.append(f"Fat target: {goal.fat_g:.0f}g")
        else:
            lines.append("\nNo active goal set.")

        lines.append(f"\nFood log — last 7 days (today is {today}):")
        if daily:
            for day, data in sorted(daily.items()):
                lines.append(
                    f"  {day}: {data['calories']:.0f} kcal | "
                    f"P:{data['protein']:.0f}g C:{data['carbs']:.0f}g F:{data['fat']:.0f}g | "
                    f"Foods: {', '.join(data['foods'][:5])}"
                    + (" ..." if len(data['foods']) > 5 else "")
                )
        else:
            lines.append("  No food logged in the last 7 days.")

        lines.append("=== END CONTEXT ===")
        lines.append(f"\nThe user says: tell me what you know about my nutrition this week.")
        return "\n".join(lines)

    async def _gemini_stream(self, history: list) -> AsyncGenerator[str, None]:
        """Run Gemini streaming in a thread, yield text chunks asynchronously."""
        model = genai.GenerativeModel(
            model_name=self.settings.gemini_model,
            system_instruction=_COACH_SYSTEM,
            generation_config=genai.GenerationConfig(
                temperature=0.5,
                top_p=0.9,
                max_output_tokens=1024,
            ),
        )

        q: sync_queue.Queue = sync_queue.Queue()
        SENTINEL = object()

        def blocking_stream():
            try:
                chat = model.start_chat(history=history[:-1])  # history without last user msg
                response = chat.send_message(history[-1]["parts"][0], stream=True)
                for chunk in response:
                    if chunk.text:
                        q.put(chunk.text)
                q.put(SENTINEL)
            except Exception as exc:
                q.put(exc)

        task = asyncio.create_task(asyncio.to_thread(blocking_stream))

        while True:
            try:
                item = q.get_nowait()
            except sync_queue.Empty:
                await asyncio.sleep(0.02)
                continue

            if item is SENTINEL:
                break
            elif isinstance(item, Exception):
                raise item
            else:
                yield item

        await task


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _sse(data: dict) -> str:
    return f"data: {json.dumps(data)}\n\n"
