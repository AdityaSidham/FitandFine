"""
Phase 4 — Meal Recommendation Service
=======================================
Generates personalised meal suggestions that fill the user's remaining
daily macro budget using Gemini.
"""
import asyncio
import json
import logging
import uuid
from datetime import date, datetime, timezone

import google.generativeai as genai
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.models.daily_log import DailyLog
from app.models.user import User
from app.models.user_goal import UserGoal
from app.schemas.ai import MealIngredient, MealRecommendation, RecommendationsResponse

logger = logging.getLogger(__name__)


class RecommendationService:

    def __init__(self, settings: Settings, db: AsyncSession):
        self.settings = settings
        self.db = db

    async def get_recommendations(self, user_id: str) -> RecommendationsResponse:
        uid = uuid.UUID(user_id)
        today = date.today()

        goal, consumed, user = await asyncio.gather(
            self._get_active_goal(uid),
            self._get_today_consumed(uid, today),
            self._get_user(uid),
        )

        # Targets
        cal_target  = float(goal.calorie_target or 2000) if goal else 2000.0
        prot_target = float(goal.protein_g or 150)       if goal else 150.0
        carb_target = float(goal.carb_g or 200)          if goal else 200.0
        fat_target  = float(goal.fat_g or 65)            if goal else 65.0

        # Remaining
        rem_cal  = max(0.0, cal_target  - consumed["calories"])
        rem_prot = max(0.0, prot_target - consumed["protein"])
        rem_carb = max(0.0, carb_target - consumed["carbs"])
        rem_fat  = max(0.0, fat_target  - consumed["fat"])

        # User context for personalisation
        restrictions = getattr(user, "dietary_restrictions", None) or []
        allergies    = getattr(user, "allergies", None) or []

        # Call Gemini
        try:
            recs_raw = await asyncio.to_thread(
                _sync_gemini_recommendations,
                rem_cal, rem_prot, rem_carb, rem_fat,
                restrictions, allergies,
                self.settings.gemini_api_key,
                self.settings.gemini_model,
            )
        except Exception as exc:
            logger.error("Recommendation Gemini error: %s", exc)
            recs_raw = []

        recommendations = []
        for r in recs_raw:
            ingredients = [
                MealIngredient(name=i.get("name", ""), quantity=i.get("quantity", ""))
                for i in (r.get("ingredients") or [])
            ]
            recommendations.append(MealRecommendation(
                meal_name=r.get("meal_name", "Meal"),
                meal_type=r.get("meal_type", "snack"),
                prep_time_minutes=r.get("prep_time_minutes"),
                ingredients=ingredients,
                calories=float(r.get("calories", 0)),
                protein_g=float(r.get("protein_g", 0)),
                carbs_g=float(r.get("carbs_g", 0)),
                fat_g=float(r.get("fat_g", 0)),
                reasoning=r.get("reasoning", ""),
            ))

        # Macro fit score — how well the top rec fills remaining macros
        fit_score = 0.0
        if recommendations and rem_cal > 0:
            top = recommendations[0]
            cal_fit  = 1 - abs(top.calories  - rem_cal)  / max(rem_cal, 1)
            prot_fit = 1 - abs(top.protein_g - rem_prot) / max(rem_prot, 1)
            fit_score = max(0.0, min(1.0, (cal_fit + prot_fit) / 2))

        return RecommendationsResponse(
            recommendations=recommendations,
            remaining_calories=round(rem_cal, 1),
            remaining_protein_g=round(rem_prot, 1),
            remaining_carbs_g=round(rem_carb, 1),
            remaining_fat_g=round(rem_fat, 1),
            macro_fit_score=round(fit_score, 2),
            generated_at=datetime.now(timezone.utc).isoformat(),
        )

    # ------------------------------------------------------------------
    # Data helpers
    # ------------------------------------------------------------------

    async def _get_active_goal(self, user_id: uuid.UUID):
        result = await self.db.execute(
            select(UserGoal).where(UserGoal.user_id == user_id, UserGoal.is_active == True).limit(1)
        )
        return result.scalar_one_or_none()

    async def _get_today_consumed(self, user_id: uuid.UUID, today: date) -> dict:
        result = await self.db.execute(
            select(
                func.coalesce(func.sum(DailyLog.calories_consumed), 0).label("cal"),
                func.coalesce(func.sum(DailyLog.protein_consumed_g), 0).label("prot"),
                func.coalesce(func.sum(DailyLog.carbs_consumed_g), 0).label("carb"),
                func.coalesce(func.sum(DailyLog.fat_consumed_g), 0).label("fat"),
            )
            .where(
                DailyLog.user_id == user_id,
                DailyLog.log_date == today,
                DailyLog.deleted_at.is_(None),
            )
        )
        row = result.one()
        return {
            "calories": float(row.cal or 0),
            "protein":  float(row.prot or 0),
            "carbs":    float(row.carb or 0),
            "fat":      float(row.fat or 0),
        }

    async def _get_user(self, user_id: uuid.UUID):
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()


# ---------------------------------------------------------------------------
# Sync Gemini helper (runs in thread pool)
# ---------------------------------------------------------------------------

_REC_SYSTEM = (
    "You are a practical meal planner. Suggest real, easy-to-prepare meals using common ingredients. "
    "Provide accurate macro estimates. Always respect dietary restrictions and allergies."
)

def _sync_gemini_recommendations(
    rem_cal: float, rem_prot: float, rem_carb: float, rem_fat: float,
    restrictions: list, allergies: list,
    api_key: str, model_name: str,
) -> list:
    prompt = f"""
The user needs to eat approximately:
- {rem_cal:.0f} more calories today
- {rem_prot:.0f}g more protein
- {rem_carb:.0f}g more carbs
- {rem_fat:.0f}g more fat

Dietary restrictions: {', '.join(restrictions) if restrictions else 'none'}
Allergies: {', '.join(allergies) if allergies else 'none'}

Suggest 3 realistic meal options. Each should approximately fill these remaining macros.
Prefer simple meals that can be prepared in under 30 minutes.

Return ONLY this JSON array (no markdown):
[
  {{
    "meal_name": "Chicken & Rice Bowl",
    "meal_type": "lunch",
    "prep_time_minutes": 20,
    "ingredients": [
      {{"name": "chicken breast", "quantity": "150g"}},
      {{"name": "brown rice", "quantity": "100g cooked"}}
    ],
    "calories": 450,
    "protein_g": 40,
    "carbs_g": 45,
    "fat_g": 8,
    "reasoning": "High protein, moderate carbs — fits your remaining targets well"
  }}
]
"""
    genai.configure(api_key=api_key)
    model = genai.GenerativeModel(
        model_name=model_name,
        system_instruction=_REC_SYSTEM,
        generation_config=genai.GenerationConfig(
            temperature=0.6,
            max_output_tokens=1024,
            response_mime_type="application/json",
        ),
    )
    response = model.generate_content(prompt)
    text = response.text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    data = json.loads(text.strip())
    return data if isinstance(data, list) else data.get("recommendations", [])
