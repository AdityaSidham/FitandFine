"""Analytics Celery tasks — Phase 3 implementation. Stubs only for Phase 1."""
from app.tasks.celery_app import celery_app


@celery_app.task(
    bind=True,
    queue="analytics",
    name="app.tasks.analytics_tasks.run_weekly_analysis",
)
def run_weekly_analysis(self, user_id: str, week_start: str) -> dict:
    """Phase 3 stub: Diet Analysis Agent + Progress Evaluator."""
    return {"user_id": user_id, "week_start": week_start, "status": "pending_phase3"}
