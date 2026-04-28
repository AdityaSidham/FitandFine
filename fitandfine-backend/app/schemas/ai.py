"""
Phase 3 + 4 — AI / Coach schemas
"""
from typing import List, Optional
from pydantic import BaseModel


# ---------------------------------------------------------------------------
# Coach chat
# ---------------------------------------------------------------------------

class CoachMessageRequest(BaseModel):
    message: str
    session_id: Optional[str] = None   # pass back to continue a session


class CoachSSEChunk(BaseModel):         # shape of each SSE data payload
    text: str = ""
    done: bool = False
    error: Optional[str] = None


# ---------------------------------------------------------------------------
# Weekly diet analysis
# ---------------------------------------------------------------------------

class WeeklyFinding(BaseModel):
    category: str                       # calories, protein, adherence, timing …
    severity: str                       # info | warning | critical
    title: str
    description: str
    recommendation: str


class WeeklyReportResponse(BaseModel):
    summary: str
    findings: List[WeeklyFinding]
    adherence_score: float              # 0.0–1.0
    period_start: str                   # YYYY-MM-DD
    period_end: str
    generated_at: str                   # ISO8601
    data_days: int                      # days with at least one log entry
    estimated_daily_deficit: Optional[float] = None   # kcal (negative = surplus)


# ---------------------------------------------------------------------------
# Phase 4 — Progress Evaluation
# ---------------------------------------------------------------------------

class GoalAdjustmentProposal(BaseModel):
    action: str                          # no_change | reduce_calories | increase_calories
    calorie_delta: int                   # e.g. -200  (always negative for reduce, positive for increase)
    new_calorie_target: int
    reasoning: str
    confidence: float                    # 0.0–1.0


class ProgressEvaluationResponse(BaseModel):
    progress_status: str                 # on_track | plateau | insufficient_data | off_track
    plateau_detected: bool
    plateau_type: Optional[str] = None  # adherence | adaptation | data_quality
    weeks_evaluated: int
    weight_readings: int                 # how many weight logs found
    avg_weekly_change_kg: Optional[float] = None
    expected_weekly_change_kg: Optional[float] = None
    adjustment: GoalAdjustmentProposal
    narrative: str                       # user-facing summary
    generated_at: str


# ---------------------------------------------------------------------------
# Phase 4 — Meal Recommendations
# ---------------------------------------------------------------------------

class MealIngredient(BaseModel):
    name: str
    quantity: str                        # e.g. "150g", "1 cup"


class MealRecommendation(BaseModel):
    meal_name: str
    meal_type: str                       # breakfast | lunch | dinner | snack
    prep_time_minutes: Optional[int] = None
    ingredients: List[MealIngredient]
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    reasoning: str                       # why this fits


class RecommendationsResponse(BaseModel):
    recommendations: List[MealRecommendation]
    remaining_calories: float
    remaining_protein_g: float
    remaining_carbs_g: float
    remaining_fat_g: float
    macro_fit_score: float               # 0.0–1.0 how well recs fill remaining macros
    generated_at: str


# ---------------------------------------------------------------------------
# Phase 4 — Apply goal adjustment
# ---------------------------------------------------------------------------

class ApplyAdjustmentRequest(BaseModel):
    new_calorie_target: int
    goal_id: str
