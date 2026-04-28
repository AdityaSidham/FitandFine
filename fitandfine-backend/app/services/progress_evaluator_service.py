"""
Phase 4 — Progress Evaluator Service
======================================
Compares actual weight trend against thermodynamic expectation to detect plateaus
and propose specific calorie target adjustments.

Algorithm:
  1. Fetch last N weeks of weight logs + average daily calories logged
  2. Compute expected weekly weight change from avg calorie surplus/deficit
     (Heuristic: 7700 kcal ≈ 1 kg body-weight change)
  3. Compare actual weekly trend (linear regression on weight readings) vs expected
  4. Classify: on_track | plateau | off_track | insufficient_data
  5. Ask Gemini to generate user-facing narrative + specific adjustment recommendation
"""
import asyncio
import json
import logging
import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Optional

import google.generativeai as genai
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.models.daily_log import DailyLog
from app.models.user_goal import UserGoal
from app.models.weight_log import WeightLog
from app.schemas.ai import GoalAdjustmentProposal, ProgressEvaluationResponse

logger = logging.getLogger(__name__)

KCAL_PER_KG = 7700.0       # rough thermodynamic constant
WEEKS_TO_ANALYSE = 4
MIN_WEIGHT_READINGS = 3    # need at least this many to compute a trend


class ProgressEvaluatorService:

    def __init__(self, settings: Settings, db: AsyncSession):
        self.settings = settings
        self.db = db

    async def evaluate(self, user_id: str) -> ProgressEvaluationResponse:
        uid = uuid.UUID(user_id)
        today = date.today()
        start = today - timedelta(weeks=WEEKS_TO_ANALYSE)

        # ── Fetch data ───────────────────────────────────────────────────
        weight_rows = await self._get_weight_logs(uid, start)
        avg_daily_cal = await self._avg_daily_calories(uid, start)
        goal = await self._get_active_goal(uid)

        calorie_target = float(goal.calorie_target or 2000) if goal else 2000.0
        goal_type = goal.goal_type if goal else "maintain"
        current_goal_id = str(goal.id) if goal else None

        # ── Insufficient data ────────────────────────────────────────────
        if len(weight_rows) < MIN_WEIGHT_READINGS:
            return self._insufficient_data_response(
                calorie_target=int(calorie_target),
                weight_count=len(weight_rows),
            )

        # ── Compute trend ────────────────────────────────────────────────
        actual_weekly_kg = self._linear_trend_per_week(weight_rows)
        avg_deficit = calorie_target - avg_daily_cal          # positive = eating less than target
        expected_weekly_kg = -avg_deficit / KCAL_PER_KG * 7  # negative = expected loss

        # For weight loss goals, expected_weekly_kg should be negative
        plateau_detected, plateau_type = self._detect_plateau(
            goal_type=goal_type,
            actual_weekly_kg=actual_weekly_kg,
            expected_weekly_kg=expected_weekly_kg,
            avg_daily_cal=avg_daily_cal,
            calorie_target=calorie_target,
        )

        progress_status = self._classify_status(
            goal_type=goal_type,
            plateau_detected=plateau_detected,
            actual_weekly_kg=actual_weekly_kg,
            expected_weekly_kg=expected_weekly_kg,
        )

        # ── Ask Gemini for narrative + adjustment ────────────────────────
        adjustment, narrative = await self._generate_recommendation(
            goal_type=goal_type,
            progress_status=progress_status,
            plateau_detected=plateau_detected,
            plateau_type=plateau_type,
            actual_weekly_kg=actual_weekly_kg,
            expected_weekly_kg=expected_weekly_kg,
            calorie_target=int(calorie_target),
            avg_daily_cal=avg_daily_cal,
            weeks=WEEKS_TO_ANALYSE,
        )

        return ProgressEvaluationResponse(
            progress_status=progress_status,
            plateau_detected=plateau_detected,
            plateau_type=plateau_type,
            weeks_evaluated=WEEKS_TO_ANALYSE,
            weight_readings=len(weight_rows),
            avg_weekly_change_kg=round(actual_weekly_kg, 3),
            expected_weekly_change_kg=round(expected_weekly_kg, 3),
            adjustment=adjustment,
            narrative=narrative,
            generated_at=datetime.now(timezone.utc).isoformat(),
        )

    # ------------------------------------------------------------------
    # Data fetchers
    # ------------------------------------------------------------------

    async def _get_weight_logs(self, user_id: uuid.UUID, since: date) -> list:
        result = await self.db.execute(
            select(WeightLog)
            .where(WeightLog.user_id == user_id, WeightLog.log_date >= since)
            .order_by(WeightLog.log_date)
        )
        return result.scalars().all()

    async def _avg_daily_calories(self, user_id: uuid.UUID, since: date) -> float:
        """Average calories consumed per logged day (ignores days with no log)."""
        result = await self.db.execute(
            select(
                DailyLog.log_date,
                func.sum(DailyLog.calories_consumed).label("day_cal"),
            )
            .where(
                DailyLog.user_id == user_id,
                DailyLog.log_date >= since,
                DailyLog.deleted_at.is_(None),
            )
            .group_by(DailyLog.log_date)
        )
        rows = result.all()
        if not rows:
            return 0.0
        return sum(float(r.day_cal or 0) for r in rows) / len(rows)

    async def _get_active_goal(self, user_id: uuid.UUID) -> Optional[UserGoal]:
        result = await self.db.execute(
            select(UserGoal)
            .where(UserGoal.user_id == user_id, UserGoal.is_active == True)
            .limit(1)
        )
        return result.scalar_one_or_none()

    # ------------------------------------------------------------------
    # Analytics helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _linear_trend_per_week(weight_logs: list) -> float:
        """Simple linear regression → slope in kg/week."""
        if len(weight_logs) < 2:
            return 0.0
        first_date = weight_logs[0].log_date
        xs = [(w.log_date - first_date).days / 7.0 for w in weight_logs]
        ys = [float(w.weight_kg) for w in weight_logs]
        n = len(xs)
        x_mean = sum(xs) / n
        y_mean = sum(ys) / n
        num = sum((x - x_mean) * (y - y_mean) for x, y in zip(xs, ys))
        den = sum((x - x_mean) ** 2 for x in xs)
        return num / den if den != 0 else 0.0

    @staticmethod
    def _detect_plateau(
        goal_type: str,
        actual_weekly_kg: float,
        expected_weekly_kg: float,
        avg_daily_cal: float,
        calorie_target: float,
    ) -> tuple[bool, Optional[str]]:
        if goal_type not in ("lose_weight", "gain_muscle"):
            return False, None

        # Determine if we expect movement
        expected_movement = abs(expected_weekly_kg) > 0.1

        if not expected_movement:
            return False, None

        actual_movement = abs(actual_weekly_kg)
        direction_match = (expected_weekly_kg < 0 and actual_weekly_kg < 0) or \
                          (expected_weekly_kg > 0 and actual_weekly_kg > 0)

        # Plateau = expected > 0.1 kg/week but actual < 0.05 kg/week
        if actual_movement < 0.05:
            adherence = avg_daily_cal / max(calorie_target, 1)
            if adherence < 0.85:
                return True, "adherence"    # not actually following the target
            else:
                return True, "adaptation"   # following but body adapted
        elif not direction_match:
            return True, "adherence"

        return False, None

    @staticmethod
    def _classify_status(
        goal_type: str,
        plateau_detected: bool,
        actual_weekly_kg: float,
        expected_weekly_kg: float,
    ) -> str:
        if plateau_detected:
            return "plateau"
        if goal_type == "lose_weight":
            if actual_weekly_kg < -0.05:
                return "on_track"
            return "off_track"
        if goal_type == "gain_muscle":
            if actual_weekly_kg > 0.05:
                return "on_track"
            return "off_track"
        return "on_track"   # maintain / recomp

    # ------------------------------------------------------------------
    # Gemini recommendation
    # ------------------------------------------------------------------

    async def _generate_recommendation(
        self, **kwargs
    ) -> tuple[GoalAdjustmentProposal, str]:
        prompt = _build_eval_prompt(**kwargs)
        try:
            data = await asyncio.to_thread(
                _sync_gemini_json,
                prompt,
                self.settings.gemini_api_key,
                self.settings.gemini_model,
            )
        except Exception as exc:
            logger.error("Progress evaluator Gemini error: %s", exc)
            # Fallback: rule-based
            return self._rule_based_adjustment(**kwargs), "Unable to generate AI analysis at this time."

        adjustment = GoalAdjustmentProposal(
            action=data.get("action", "no_change"),
            calorie_delta=int(data.get("calorie_delta", 0)),
            new_calorie_target=int(data.get("new_calorie_target", kwargs["calorie_target"])),
            reasoning=data.get("reasoning", ""),
            confidence=float(data.get("confidence", 0.5)),
        )
        return adjustment, data.get("narrative", "")

    @staticmethod
    def _rule_based_adjustment(
        goal_type: str, plateau_detected: bool, calorie_target: int,
        actual_weekly_kg: float, **_
    ) -> GoalAdjustmentProposal:
        if not plateau_detected or goal_type == "maintain":
            return GoalAdjustmentProposal(
                action="no_change", calorie_delta=0,
                new_calorie_target=calorie_target,
                reasoning="Progress is on track.", confidence=0.7,
            )
        delta = -200 if goal_type == "lose_weight" else 200
        return GoalAdjustmentProposal(
            action="reduce_calories" if delta < 0 else "increase_calories",
            calorie_delta=delta,
            new_calorie_target=calorie_target + delta,
            reasoning="Plateau detected. Adjusting calorie target.",
            confidence=0.6,
        )

    @staticmethod
    def _insufficient_data_response(calorie_target: int, weight_count: int):
        return ProgressEvaluationResponse(
            progress_status="insufficient_data",
            plateau_detected=False,
            plateau_type=None,
            weeks_evaluated=WEEKS_TO_ANALYSE,
            weight_readings=weight_count,
            avg_weekly_change_kg=None,
            expected_weekly_change_kg=None,
            adjustment=GoalAdjustmentProposal(
                action="no_change", calorie_delta=0,
                new_calorie_target=calorie_target,
                reasoning="Not enough weight data to evaluate progress.",
                confidence=0.0,
            ),
            narrative=f"Log your weight at least {MIN_WEIGHT_READINGS} times over 4 weeks to unlock progress evaluation.",
            generated_at=datetime.now(timezone.utc).isoformat(),
        )


# ---------------------------------------------------------------------------
# Prompt builder & sync Gemini helper
# ---------------------------------------------------------------------------

def _build_eval_prompt(
    goal_type, progress_status, plateau_detected, plateau_type,
    actual_weekly_kg, expected_weekly_kg, calorie_target, avg_daily_cal, weeks, **_
) -> str:
    return f"""
You are a nutrition progress analyst. Evaluate a user's {weeks}-week progress data.

GOAL TYPE: {goal_type.replace('_', ' ')}
CURRENT CALORIE TARGET: {calorie_target} kcal/day
AVERAGE DAILY CALORIES LOGGED: {avg_daily_cal:.0f} kcal/day
ACTUAL WEEKLY WEIGHT CHANGE: {actual_weekly_kg:+.2f} kg/week
EXPECTED WEEKLY WEIGHT CHANGE: {expected_weekly_kg:+.2f} kg/week
PLATEAU DETECTED: {plateau_detected}
PLATEAU TYPE: {plateau_type or 'none'}
STATUS CLASSIFICATION: {progress_status}

Rules:
- For lose_weight goals: target -0.25 to -0.75 kg/week (safe range)
- For gain_muscle goals: target +0.1 to +0.3 kg/week
- Max calorie reduction: -300 kcal/day in one adjustment
- Max calorie increase: +300 kcal/day in one adjustment
- Minimum safe calorie floor: 1200 (women) / 1500 (men) — use 1400 as a safe default
- If plateau_type is "adherence", recommend improving consistency first (no_change)
- If plateau_type is "adaptation", reduce calories by 150-250 kcal
- narrative should be warm, encouraging, and specific (2-3 sentences)

Return ONLY this JSON (no markdown):
{{
  "action": "no_change|reduce_calories|increase_calories",
  "calorie_delta": 0,
  "new_calorie_target": {calorie_target},
  "reasoning": "specific 1-sentence explanation",
  "confidence": 0.0,
  "narrative": "user-facing 2-3 sentence summary with encouragement"
}}
"""


def _sync_gemini_json(prompt: str, api_key: str, model_name: str) -> dict:
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel(
        model_name=model_name,
        generation_config=genai.GenerationConfig(
            temperature=0.2,
            max_output_tokens=512,
            response_mime_type="application/json",
        ),
    )
    response = model.generate_content(prompt)
    text = response.text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())
