"""Initial schema — all 7 tables.

Revision ID: 001_initial
Revises: None
Create Date: 2026-04-07
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# ---------------------------------------------------------------------------
# Revision identifiers
# ---------------------------------------------------------------------------
revision = "001_initial"
down_revision = None
branch_labels = None
depends_on = None


# ---------------------------------------------------------------------------
# Upgrade
# ---------------------------------------------------------------------------

def upgrade() -> None:
    # ------------------------------------------------------------------
    # 1. users
    # ------------------------------------------------------------------
    op.create_table(
        "users",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("email", sa.VARCHAR(255), unique=True, nullable=True),
        sa.Column("apple_user_id", sa.VARCHAR(255), unique=True, nullable=True),
        sa.Column("google_user_id", sa.VARCHAR(255), unique=True, nullable=True),
        sa.Column("display_name", sa.VARCHAR(100), nullable=True),
        sa.Column("date_of_birth", sa.Date(), nullable=True),
        sa.Column("sex", sa.VARCHAR(10), nullable=True),
        sa.Column("height_cm", sa.Numeric(5, 2), nullable=True),
        sa.Column("activity_level", sa.VARCHAR(30), nullable=True),
        sa.Column(
            "timezone",
            sa.VARCHAR(50),
            nullable=False,
            server_default=sa.text("'UTC'"),
        ),
        sa.Column(
            "dietary_restrictions",
            postgresql.ARRAY(sa.VARCHAR()),
            nullable=True,
        ),
        sa.Column("allergies", postgresql.ARRAY(sa.VARCHAR()), nullable=True),
        sa.Column(
            "preferred_cuisine",
            postgresql.ARRAY(sa.VARCHAR()),
            nullable=True,
        ),
        sa.Column("budget_per_meal_usd", sa.Numeric(6, 2), nullable=True),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("deleted_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )

    # ------------------------------------------------------------------
    # 2. user_goals
    # ------------------------------------------------------------------
    op.create_table(
        "user_goals",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("goal_type", sa.VARCHAR(30), nullable=False),
        sa.Column("target_weight_kg", sa.Numeric(5, 2), nullable=True),
        sa.Column("target_date", sa.Date(), nullable=True),
        sa.Column("calorie_target", sa.Integer(), nullable=True),
        sa.Column("protein_pct", sa.Numeric(5, 2), nullable=True),
        sa.Column("carb_pct", sa.Numeric(5, 2), nullable=True),
        sa.Column("fat_pct", sa.Numeric(5, 2), nullable=True),
        sa.Column("protein_g", sa.Numeric(6, 2), nullable=True),
        sa.Column("carb_g", sa.Numeric(6, 2), nullable=True),
        sa.Column("fat_g", sa.Numeric(6, 2), nullable=True),
        sa.Column("weekly_weight_change_target_kg", sa.Numeric(4, 2), nullable=True),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    # ------------------------------------------------------------------
    # 3. food_items
    # ------------------------------------------------------------------
    op.create_table(
        "food_items",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("name", sa.VARCHAR(255), nullable=False),
        sa.Column("brand", sa.VARCHAR(255), nullable=True),
        sa.Column("barcode", sa.VARCHAR(100), nullable=True),
        sa.Column("barcode_type", sa.VARCHAR(20), nullable=True),
        sa.Column("source", sa.VARCHAR(30), nullable=False),
        sa.Column("external_id", sa.VARCHAR(100), nullable=True),
        sa.Column("serving_size_g", sa.Numeric(8, 3), nullable=True),
        sa.Column("serving_size_description", sa.VARCHAR(100), nullable=True),
        sa.Column("calories", sa.Numeric(8, 2), nullable=True),
        sa.Column("protein_g", sa.Numeric(8, 3), nullable=True),
        sa.Column("carbohydrates_g", sa.Numeric(8, 3), nullable=True),
        sa.Column("fat_g", sa.Numeric(8, 3), nullable=True),
        sa.Column("fiber_g", sa.Numeric(8, 3), nullable=True),
        sa.Column("sugar_g", sa.Numeric(8, 3), nullable=True),
        sa.Column("sodium_mg", sa.Numeric(8, 3), nullable=True),
        sa.Column("cholesterol_mg", sa.Numeric(8, 3), nullable=True),
        sa.Column("saturated_fat_g", sa.Numeric(8, 3), nullable=True),
        sa.Column("trans_fat_g", sa.Numeric(8, 3), nullable=True),
        sa.Column("vitamins", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("minerals", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("ingredients_text", sa.Text(), nullable=True),
        sa.Column("allergen_flags", postgresql.ARRAY(sa.VARCHAR()), nullable=True),
        sa.Column(
            "is_verified",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column("confidence_score", sa.Numeric(3, 2), nullable=True),
        sa.Column(
            "created_by_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    # ------------------------------------------------------------------
    # 4. daily_logs
    # ------------------------------------------------------------------
    op.create_table(
        "daily_logs",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "food_item_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("food_items.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("log_date", sa.Date(), nullable=False),
        sa.Column("log_time", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("meal_type", sa.VARCHAR(20), nullable=False),
        sa.Column("quantity", sa.Numeric(10, 3), nullable=False),
        sa.Column("serving_description", sa.VARCHAR(100), nullable=True),
        sa.Column("calories_consumed", sa.Numeric(8, 2), nullable=False),
        sa.Column("protein_consumed_g", sa.Numeric(8, 3), nullable=False),
        sa.Column("carbs_consumed_g", sa.Numeric(8, 3), nullable=False),
        sa.Column("fat_consumed_g", sa.Numeric(8, 3), nullable=False),
        sa.Column("entry_method", sa.VARCHAR(30), nullable=True),
        sa.Column("scan_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("deleted_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )

    # ------------------------------------------------------------------
    # 5. weight_logs
    # ------------------------------------------------------------------
    op.create_table(
        "weight_logs",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("log_date", sa.Date(), nullable=False),
        sa.Column("log_time", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("weight_kg", sa.Numeric(5, 2), nullable=False),
        sa.Column("body_fat_pct", sa.Numeric(5, 2), nullable=True),
        sa.Column("muscle_mass_kg", sa.Numeric(5, 2), nullable=True),
        sa.Column("water_pct", sa.Numeric(5, 2), nullable=True),
        sa.Column("measurement_source", sa.VARCHAR(30), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    # ------------------------------------------------------------------
    # 6. ai_conversations
    # ------------------------------------------------------------------
    op.create_table(
        "ai_conversations",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("agent_type", sa.VARCHAR(30), nullable=False),
        sa.Column("session_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("messages", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column(
            "context_snapshot",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
        sa.Column("tokens_input", sa.Integer(), nullable=True),
        sa.Column("tokens_output", sa.Integer(), nullable=True),
        sa.Column("model_version", sa.VARCHAR(50), nullable=True),
        sa.Column("trigger_type", sa.VARCHAR(30), nullable=True),
        sa.Column(
            "trigger_context",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    # ------------------------------------------------------------------
    # 7. scan_history
    # ------------------------------------------------------------------
    op.create_table(
        "scan_history",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("image_s3_key", sa.VARCHAR(500), nullable=True),
        sa.Column("image_s3_bucket", sa.VARCHAR(100), nullable=True),
        sa.Column("scan_type", sa.VARCHAR(20), nullable=False),
        sa.Column("ocr_raw_text", sa.Text(), nullable=True),
        sa.Column("ocr_confidence", sa.Numeric(5, 4), nullable=True),
        sa.Column(
            "parsed_result",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
        sa.Column(
            "food_item_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("food_items.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "processing_status",
            sa.VARCHAR(20),
            nullable=False,
            server_default=sa.text("'pending'"),
        ),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("celery_task_id", sa.VARCHAR(255), nullable=True),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("completed_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )

    # ------------------------------------------------------------------
    # Indexes
    # ------------------------------------------------------------------

    # user_goals
    op.create_index("ix_user_goals_user_id", "user_goals", ["user_id"])
    op.create_index(
        "ix_user_goals_user_id_active", "user_goals", ["user_id", "is_active"]
    )

    # food_items
    op.create_index(
        "ix_food_items_barcode",
        "food_items",
        ["barcode"],
        postgresql_where=sa.text("barcode IS NOT NULL"),
    )
    op.create_index(
        "ix_food_items_source_external",
        "food_items",
        ["source", "external_id"],
        postgresql_where=sa.text("external_id IS NOT NULL"),
    )
    op.execute(
        "CREATE INDEX ix_food_items_fts ON food_items "
        "USING GIN (to_tsvector('english', coalesce(name,'') || ' ' || coalesce(brand,'')))"
    )

    # daily_logs
    op.create_index(
        "ix_daily_logs_user_id_log_date", "daily_logs", ["user_id", "log_date"]
    )
    op.create_index(
        "ix_daily_logs_user_id_log_time", "daily_logs", ["user_id", "log_time"]
    )

    # weight_logs
    op.create_index(
        "ix_weight_logs_user_id_log_date", "weight_logs", ["user_id", "log_date"]
    )
    op.create_unique_constraint(
        "uq_weight_logs_user_date", "weight_logs", ["user_id", "log_date"]
    )

    # ai_conversations
    op.create_index(
        "ix_ai_conversations_user_agent_created",
        "ai_conversations",
        ["user_id", "agent_type", "created_at"],
    )
    op.create_index(
        "ix_ai_conversations_session_id", "ai_conversations", ["session_id"]
    )

    # scan_history
    op.create_index(
        "ix_scan_history_user_id_created_at",
        "scan_history",
        ["user_id", "created_at"],
    )
    op.create_index(
        "ix_scan_history_status",
        "scan_history",
        ["processing_status"],
        postgresql_where=sa.text("processing_status IN ('pending', 'processing')"),
    )


# ---------------------------------------------------------------------------
# Downgrade
# ---------------------------------------------------------------------------

def downgrade() -> None:
    # Drop indexes first (reverse order of creation).
    op.drop_index("ix_scan_history_status", table_name="scan_history")
    op.drop_index("ix_scan_history_user_id_created_at", table_name="scan_history")
    op.drop_index(
        "ix_ai_conversations_session_id", table_name="ai_conversations"
    )
    op.drop_index(
        "ix_ai_conversations_user_agent_created", table_name="ai_conversations"
    )
    op.drop_constraint(
        "uq_weight_logs_user_date", "weight_logs", type_="unique"
    )
    op.drop_index("ix_weight_logs_user_id_log_date", table_name="weight_logs")
    op.drop_index("ix_daily_logs_user_id_log_time", table_name="daily_logs")
    op.drop_index("ix_daily_logs_user_id_log_date", table_name="daily_logs")
    op.execute("DROP INDEX IF EXISTS ix_food_items_fts")
    op.drop_index("ix_food_items_source_external", table_name="food_items")
    op.drop_index("ix_food_items_barcode", table_name="food_items")
    op.drop_index("ix_user_goals_user_id_active", table_name="user_goals")
    op.drop_index("ix_user_goals_user_id", table_name="user_goals")

    # Drop tables in reverse FK-safe order.
    op.drop_table("scan_history")
    op.drop_table("ai_conversations")
    op.drop_table("weight_logs")
    op.drop_table("daily_logs")
    op.drop_table("food_items")
    op.drop_table("user_goals")
    op.drop_table("users")
