"""
Phase 3 + 4 — AI / Coach API
==============================
POST /ai/coach/message        → SSE stream of coach reply chunks
GET  /ai/weekly-report        → Structured 7-day diet analysis
GET  /ai/coach/history        → Recent conversation sessions
GET  /ai/progress-evaluation  → Plateau detection + goal adjustment proposal
POST /ai/progress-evaluation/apply → Apply proposed calorie adjustment
GET  /ai/recommendations      → Meal suggestions for remaining macros
"""
import uuid
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.dependencies import get_current_user_id, get_db
from app.models.ai_conversation import AIConversation
from app.repositories.goal_repository import GoalRepository
from app.schemas.ai import (
    ApplyAdjustmentRequest,
    CoachMessageRequest,
    ProgressEvaluationResponse,
    RecommendationsResponse,
    WeeklyReportResponse,
)
from app.services.coach_service import CoachService
from app.services.diet_analysis_service import DietAnalysisService
from app.services.progress_evaluator_service import ProgressEvaluatorService
from app.services.recommendation_service import RecommendationService

logger = logging.getLogger(__name__)
router = APIRouter()


# ---------------------------------------------------------------------------
# POST /ai/coach/message — streaming SSE
# ---------------------------------------------------------------------------

@router.post(
    "/coach/message",
    summary="Send a message to the AI nutrition coach (SSE streaming)",
)
async def coach_message(
    body: CoachMessageRequest,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user_id),
    settings: Settings = Depends(get_settings),
):
    """
    Returns a Server-Sent Events stream.
    Each event: data: {"text": "...", "done": false}
    Final event: data: {"text": "", "done": true}
    """
    service = CoachService(settings)
    generator = service.stream_response(
        user_id=str(user_id),
        message=body.message,
        db=db,
        session_id=body.session_id,
    )
    return StreamingResponse(
        generator,
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",   # Disable Nginx buffering for SSE
        },
    )


# ---------------------------------------------------------------------------
# GET /ai/weekly-report
# ---------------------------------------------------------------------------

@router.get(
    "/weekly-report",
    response_model=WeeklyReportResponse,
    summary="Get the AI-generated weekly diet analysis",
)
async def weekly_report(
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user_id),
    settings: Settings = Depends(get_settings),
):
    """
    Analyzes the last 7 days of food logs against the user's goals.
    Results are cached for 24 hours — subsequent calls within that window
    return instantly without calling the AI.
    """
    service = DietAnalysisService(settings=settings, db=db)
    try:
        return await service.get_weekly_report(user_id=str(user_id))
    except RuntimeError as exc:
        err = str(exc).lower()
        if "quota" in err or "429" in err:
            raise HTTPException(
                status_code=429,
                detail="Gemini API quota exhausted. Update GEMINI_API_KEY in .env.",
            )
        raise HTTPException(status_code=503, detail="AI analysis temporarily unavailable.")


# ---------------------------------------------------------------------------
# GET /ai/coach/history
# ---------------------------------------------------------------------------

@router.get(
    "/coach/history",
    summary="List recent coach conversation sessions",
)
async def coach_history(
    limit: int = 5,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user_id),
):
    """Returns the N most recent coach sessions with message counts."""
    result = await db.execute(
        select(AIConversation)
        .where(
            AIConversation.user_id == user_id,
            AIConversation.agent_type == "coach",
        )
        .order_by(desc(AIConversation.created_at))
        .limit(limit)
    )
    convs = result.scalars().all()

    return [
        {
            "session_id": str(c.session_id),
            "message_count": len(c.messages or []),
            "created_at": c.created_at.isoformat() if c.created_at else None,
            "updated_at": c.updated_at.isoformat() if c.updated_at else None,
            "preview": _preview(c.messages),
        }
        for c in convs
    ]


# ---------------------------------------------------------------------------
# GET /ai/progress-evaluation
# ---------------------------------------------------------------------------

@router.get(
    "/progress-evaluation",
    response_model=ProgressEvaluationResponse,
    summary="Evaluate weight progress and detect plateaus (Phase 4)",
)
async def progress_evaluation(
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user_id),
    settings: Settings = Depends(get_settings),
):
    """
    Analyses last 4 weeks of weight logs + food logs.
    Returns plateau status, expected vs actual weight change,
    and a specific calorie adjustment proposal if needed.
    """
    service = ProgressEvaluatorService(settings=settings, db=db)
    try:
        return await service.evaluate(user_id=str(user_id))
    except Exception as exc:
        logger.error("Progress evaluation error (user=%s): %s", user_id, exc)
        raise HTTPException(status_code=503, detail="Progress evaluation temporarily unavailable.")


# ---------------------------------------------------------------------------
# POST /ai/progress-evaluation/apply
# ---------------------------------------------------------------------------

@router.post(
    "/progress-evaluation/apply",
    summary="Apply an AI-proposed calorie target adjustment (Phase 4)",
)
async def apply_goal_adjustment(
    body: ApplyAdjustmentRequest,
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user_id),
):
    """
    User-confirmed: updates the calorie target (and recomputes macro grams)
    on the specified goal. The AI NEVER applies adjustments silently —
    this endpoint requires explicit user action.
    """
    repo = GoalRepository(db)
    try:
        goal_id = uuid.UUID(body.goal_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid goal_id.")

    goal = await repo.get_by_id(goal_id)
    if goal is None or goal.user_id != user_id:
        raise HTTPException(status_code=404, detail="Goal not found.")

    # Recompute macro grams from new calorie target preserving existing pcts
    from app.services.macro_service import calculate_macro_grams
    prot_pct = float(goal.protein_pct or 30)
    carb_pct = float(goal.carb_pct or 40)
    fat_pct  = float(goal.fat_pct or 30)
    macros = calculate_macro_grams(body.new_calorie_target, prot_pct, carb_pct, fat_pct)

    updated = await repo.update(
        goal,
        calorie_target=body.new_calorie_target,
        protein_g=macros["protein_g"],
        carb_g=macros["carb_g"],
        fat_g=macros["fat_g"],
    )
    from app.schemas.goal import GoalResponse
    return GoalResponse.model_validate(updated, from_attributes=True)


# ---------------------------------------------------------------------------
# GET /ai/recommendations
# ---------------------------------------------------------------------------

@router.get(
    "/recommendations",
    response_model=RecommendationsResponse,
    summary="Get meal recommendations to fill remaining daily macros (Phase 4)",
)
async def get_recommendations(
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(get_current_user_id),
    settings: Settings = Depends(get_settings),
):
    """
    Calculates today's remaining macro budget (goal − already logged)
    and returns 3 AI-generated meal suggestions that fit.
    """
    service = RecommendationService(settings=settings, db=db)
    try:
        return await service.get_recommendations(user_id=str(user_id))
    except Exception as exc:
        err = str(exc).lower()
        if "quota" in err or "429" in err:
            raise HTTPException(status_code=429, detail="Gemini quota exhausted.")
        logger.error("Recommendation error (user=%s): %s", user_id, exc)
        raise HTTPException(status_code=503, detail="Recommendation service temporarily unavailable.")


def _preview(messages: list | None) -> str:
    """First user message as preview text."""
    if not messages:
        return ""
    for msg in messages:
        if msg.get("role") == "user":
            parts = msg.get("parts", [])
            if parts:
                text = str(parts[0])
                # Skip context injection messages
                if "=== USER CONTEXT" not in text:
                    return text[:80] + ("…" if len(text) > 80 else "")
    return ""
