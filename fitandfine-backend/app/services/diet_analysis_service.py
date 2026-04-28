"""
Phase 3 — Diet Analysis Service
=================================
Analyzes the user's last 7 days of food logs against their goal.
Returns structured findings with severity ratings.
Uses Gemini with JSON output mode.
"""
import asyncio
import logging
import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.models.ai_conversation import AIConversation
from app.models.daily_log import DailyLog
from app.models.food_item import FoodItem
from app.models.user import User
from app.models.user_goal import UserGoal
from app.schemas.ai import WeeklyFinding, WeeklyReportResponse
from app.services.ai_service import generate_json

logger = logging.getLogger(__name__)

_ANALYSIS_SYSTEM = """\
You are an evidence-based nutrition pattern analyst. You receive a user's 7-day food log summary \
and their calorie/macro targets, then produce a structured analysis JSON.

Rules:
- Base all findings on the data provided — never fabricate trends
- If fewer than 3 days have data, set adherence_score low and flag as "insufficient_data"
- Identify real patterns: consistent under-eating, protein gaps, carb spikes, meal skipping
- Each finding must have a concrete, actionable recommendation
- Severity: "info" = notable but fine, "warning" = needs attention, "critical" = health/goal risk
- estimated_daily_deficit is calories: negative means surplus (eating MORE than target)
- Be constructive and encouraging, not preachy
"""

_ANALYSIS_PROMPT_TEMPLATE = """\
Analyze this user's nutrition data for {period_start} to {period_end} ({data_days} days with logs).

GOALS:
- Daily calorie target: {calorie_target} kcal
- Protein target: {protein_g}g
- Carb target: {carb_g}g
- Fat target: {fat_g}g
- Goal type: {goal_type}

DAILY LOG SUMMARY:
{daily_summary}

AVERAGES (logged days only):
- Avg calories: {avg_cal:.0f} kcal
- Avg protein: {avg_protein:.1f}g
- Avg carbs: {avg_carb:.1f}g
- Avg fat: {avg_fat:.1f}g
- Days logged: {data_days} / 7

Return ONLY this JSON (no markdown):
{{
  "summary": "2-3 sentence executive summary of the week",
  "findings": [
    {{
      "category": "calories|protein|carbs|fat|adherence|meal_timing|data_quality",
      "severity": "info|warning|critical",
      "title": "short title",
      "description": "1-2 sentences describing the pattern",
      "recommendation": "specific, actionable advice"
    }}
  ],
  "adherence_score": 0.0,
  "estimated_daily_deficit": 0.0
}}

Include 2–5 findings. adherence_score is 0.0–1.0 (ratio of days logged × target hit accuracy).
estimated_daily_deficit is (target_calories - avg_calories_logged); positive = deficit, negative = surplus.
"""


class DietAnalysisService:
    """Analyze the user's weekly diet pattern with Gemini."""

    def __init__(self, settings: Settings, db: AsyncSession):
        self.settings = settings
        self.db = db

    async def get_weekly_report(self, user_id: str) -> WeeklyReportResponse:
        """
        Returns a cached report if generated within the last 24 hours,
        otherwise generates a fresh one.
        """
        uid = uuid.UUID(user_id)
        today = date.today()
        period_start = today - timedelta(days=6)

        # Check cache in ai_conversations
        cached = await self._get_cached_report(uid, period_start)
        if cached:
            return cached

        # Generate fresh analysis
        report = await self._generate_report(uid, period_start, today)

        # Persist for caching
        await self._cache_report(uid, period_start, report)
        return report

    # ------------------------------------------------------------------
    # Private
    # ------------------------------------------------------------------

    async def _get_cached_report(
        self, user_id: uuid.UUID, period_start: date
    ) -> Optional[WeeklyReportResponse]:
        """Return cached report if available and < 24h old."""
        result = await self.db.execute(
            select(AIConversation)
            .where(
                AIConversation.user_id == user_id,
                AIConversation.agent_type == "diet_analyzer",
                AIConversation.trigger_context["period_start"].astext == str(period_start),
            )
            .order_by(AIConversation.created_at.desc())
            .limit(1)
        )
        conv = result.scalar_one_or_none()
        if not conv or not conv.context_snapshot:
            return None

        # Check freshness (24h)
        age = datetime.now(timezone.utc) - conv.created_at.replace(tzinfo=timezone.utc)
        if age.total_seconds() > 86400:
            return None

        try:
            return WeeklyReportResponse(**conv.context_snapshot)
        except Exception:
            return None

    async def _generate_report(
        self, user_id: uuid.UUID, period_start: date, period_end: date
    ) -> WeeklyReportResponse:
        """Fetch data, call Gemini, parse response."""
        # --- Fetch goal ---
        goal_result = await self.db.execute(
            select(UserGoal)
            .where(UserGoal.user_id == user_id, UserGoal.is_active == True)
            .limit(1)
        )
        goal = goal_result.scalar_one_or_none()

        calorie_target = float(goal.calorie_target or 2000) if goal else 2000.0
        protein_g = float(goal.protein_g or 0) if goal else 0.0
        carb_g = float(goal.carb_g or 0) if goal else 0.0
        fat_g = float(goal.fat_g or 0) if goal else 0.0
        goal_type = goal.goal_type if goal else "maintain"

        # --- Fetch logs ---
        logs_result = await self.db.execute(
            select(DailyLog, FoodItem)
            .join(FoodItem, DailyLog.food_item_id == FoodItem.id)
            .where(
                DailyLog.user_id == user_id,
                DailyLog.log_date >= period_start,
                DailyLog.log_date <= period_end,
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
                daily[key] = {"calories": 0, "protein": 0, "carbs": 0, "fat": 0}
            daily[key]["calories"] += float(log.calories_consumed or 0)
            daily[key]["protein"]  += float(log.protein_consumed_g or 0)
            daily[key]["carbs"]    += float(log.carbs_consumed_g or 0)
            daily[key]["fat"]      += float(log.fat_consumed_g or 0)

        data_days = len(daily)

        # Build summary text for prompt
        lines = []
        for day in sorted(daily.keys()):
            d = daily[day]
            lines.append(
                f"  {day}: {d['calories']:.0f} kcal | "
                f"P:{d['protein']:.0f}g C:{d['carbs']:.0f}g F:{d['fat']:.0f}g"
            )
        if not lines:
            lines = ["  No food logged this week."]

        avg_cal    = sum(d["calories"] for d in daily.values()) / max(data_days, 1)
        avg_protein = sum(d["protein"] for d in daily.values()) / max(data_days, 1)
        avg_carb   = sum(d["carbs"] for d in daily.values()) / max(data_days, 1)
        avg_fat    = sum(d["fat"] for d in daily.values()) / max(data_days, 1)

        prompt = _ANALYSIS_PROMPT_TEMPLATE.format(
            period_start=period_start,
            period_end=period_end,
            data_days=data_days,
            calorie_target=calorie_target,
            protein_g=protein_g,
            carb_g=carb_g,
            fat_g=fat_g,
            goal_type=goal_type.replace("_", " "),
            daily_summary="\n".join(lines),
            avg_cal=avg_cal,
            avg_protein=avg_protein,
            avg_carb=avg_carb,
            avg_fat=avg_fat,
        )

        # Call Gemini (blocking → thread)
        try:
            data = await asyncio.to_thread(
                _sync_generate_json, prompt, _ANALYSIS_SYSTEM, self.settings.gemini_api_key, self.settings.gemini_model
            )
        except Exception as exc:
            logger.error("Diet analysis Gemini error: %s", exc)
            raise RuntimeError(f"AI analysis failed: {exc}") from exc

        findings = [WeeklyFinding(**f) for f in (data.get("findings") or [])]
        now_str = datetime.now(timezone.utc).isoformat()

        return WeeklyReportResponse(
            summary=data.get("summary", "Analysis complete."),
            findings=findings,
            adherence_score=float(data.get("adherence_score", 0.0)),
            period_start=str(period_start),
            period_end=str(period_end),
            generated_at=now_str,
            data_days=data_days,
            estimated_daily_deficit=data.get("estimated_daily_deficit"),
        )

    async def _cache_report(
        self, user_id: uuid.UUID, period_start: date, report: WeeklyReportResponse
    ):
        conv = AIConversation(
            user_id=user_id,
            agent_type="diet_analyzer",
            session_id=uuid.uuid4(),
            messages=[],
            context_snapshot=report.model_dump(),
            trigger_type="on_demand",
            trigger_context={"period_start": str(period_start)},
        )
        self.db.add(conv)
        await self.db.commit()


# ---------------------------------------------------------------------------
# Sync helper (runs in thread)
# ---------------------------------------------------------------------------

def _sync_generate_json(prompt: str, system: str, api_key: str, model_name: str) -> dict:
    import json
    import google.generativeai as genai
    from google.generativeai.types import GenerationConfig

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel(
        model_name=model_name,
        system_instruction=system,
        generation_config=GenerationConfig(
            temperature=0.2,
            max_output_tokens=2048,
            response_mime_type="application/json",
        ),
    )
    response = model.generate_content(prompt)
    text = response.text.strip()
    if text.startswith("```"):
        parts = text.split("```")
        text = parts[1] if len(parts) >= 2 else text
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())
