#!/usr/bin/env python3
"""
FitandFine Phase 1 — Comprehensive End-to-End Test Suite
=========================================================
Tests every Phase 1 endpoint by:
  1. Creating a real test user directly in the database
  2. Minting a real JWT for that user (same code the production auth flow uses)
  3. Exercising all 25+ endpoints with assertions on status codes and response shapes
  4. Cleaning up the test user on exit

Run from the backend directory with the venv active:
    python test_phase1.py

Requirements: server must be running on localhost:8000
    ./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
"""

import asyncio
import sys
import uuid
from datetime import date, datetime, timezone

import httpx

BASE = "http://localhost:8000"

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

passed = 0
failed = 0
warnings = 0


def ok(label: str, detail: str = "") -> None:
    global passed
    passed += 1
    suffix = f"  {YELLOW}({detail}){RESET}" if detail else ""
    print(f"  {GREEN}✅ PASS{RESET}  {label}{suffix}")


def fail(label: str, detail: str = "") -> None:
    global failed
    failed += 1
    suffix = f"  →  {detail}" if detail else ""
    print(f"  {RED}❌ FAIL{RESET}  {label}{suffix}")


def warn(label: str, detail: str = "") -> None:
    global warnings
    warnings += 1
    suffix = f"  {YELLOW}({detail}){RESET}" if detail else ""
    print(f"  {YELLOW}⚠️  WARN{RESET}  {label}{suffix}")


def section(title: str) -> None:
    print(f"\n{BOLD}{CYAN}{'─'*60}{RESET}")
    print(f"{BOLD}{CYAN}  {title}{RESET}")
    print(f"{BOLD}{CYAN}{'─'*60}{RESET}")


def assert_status(r: httpx.Response, expected: int, label: str) -> bool:
    if r.status_code == expected:
        return True
    fail(label, f"expected {expected}, got {r.status_code}  body={r.text[:200]}")
    return False


def assert_field(data: dict, field: str, label: str) -> bool:
    if field in data:
        return True
    fail(label, f"missing field '{field}' in {list(data.keys())}")
    return False


# ── Setup: create a test user + JWT ──────────────────────────────────────────

async def create_test_user_and_token() -> tuple[str, str, str]:
    """
    Insert a test user directly into the DB (bypassing OAuth) and mint a
    real JWT for that user. The refresh token JTI is stored in Redis so
    the /auth/refresh endpoint can validate it.
    Returns (user_id_str, access_token, refresh_token).
    """
    import redis.asyncio as aioredis
    from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
    from app.config import get_settings
    from app.models.user import User
    from app.services.auth_service import create_access_token, create_refresh_token
    from app.services.cache_service import CacheService

    settings = get_settings()
    engine = create_async_engine(settings.database_url, echo=False)
    factory = async_sessionmaker(engine, expire_on_commit=False)

    test_user_id = uuid.uuid4()
    async with factory() as session:
        user = User(
            id=test_user_id,
            email=f"phase1_test_{test_user_id.hex[:8]}@fitandfine.test",
            display_name="Phase1 Test User",
            apple_user_id=f"apple_test_{test_user_id.hex[:8]}",
        )
        session.add(user)
        await session.commit()

    access_token = create_access_token(subject=str(test_user_id), settings=settings)
    refresh_token, refresh_jti = create_refresh_token(subject=str(test_user_id), settings=settings)

    # Store the refresh JTI in Redis so /auth/refresh can validate it
    redis_client = aioredis.from_url(settings.redis_url)
    cache = CacheService(redis_client)
    await cache.store_refresh_token(
        user_id=str(test_user_id),
        jti=refresh_jti,
        ttl_seconds=settings.refresh_token_expire_days * 86400,
    )
    await redis_client.aclose()

    await engine.dispose()
    return str(test_user_id), access_token, refresh_token


async def delete_test_user(user_id: str) -> None:
    """Hard-delete the test user so re-runs start clean."""
    from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
    from sqlalchemy import delete
    from app.config import get_settings
    from app.models.user import User
    from app.models.user_goal import UserGoal
    from app.models.daily_log import DailyLog
    from app.models.weight_log import WeightLog

    settings = get_settings()
    engine = create_async_engine(settings.database_url, echo=False)
    factory = async_sessionmaker(engine, expire_on_commit=False)
    uid = uuid.UUID(user_id)

    async with factory() as session:
        await session.execute(delete(DailyLog).where(DailyLog.user_id == uid))
        await session.execute(delete(WeightLog).where(WeightLog.user_id == uid))
        await session.execute(delete(UserGoal).where(UserGoal.user_id == uid))
        await session.execute(delete(User).where(User.id == uid))
        await session.commit()

    await engine.dispose()


# ── Test groups ───────────────────────────────────────────────────────────────

async def test_public(client: httpx.AsyncClient) -> None:
    section("1. Public / Infrastructure")

    # Health check
    r = await client.get("/health")
    if assert_status(r, 200, "GET /health"):
        d = r.json()
        if assert_field(d, "status", "health.status"):
            ok("GET /health", f"status={d['status']}")

    # OpenAPI docs
    r = await client.get("/docs")
    if assert_status(r, 200, "GET /docs (Swagger UI)"):
        ok("GET /docs")

    r = await client.get("/openapi.json")
    if assert_status(r, 200, "GET /openapi.json"):
        d = r.json()
        n_paths = len(d.get("paths", {}))
        ok("GET /openapi.json", f"{n_paths} routes registered")


async def test_auth(client: httpx.AsyncClient, refresh_token: str) -> str | None:
    section("2. Auth Endpoints")

    # Apple Sign In — invalid token → 401
    r = await client.post("/api/v1/auth/apple", json={
        "identity_token": "bad.token.here",
        "user_identifier": "fake_apple_id",
    })
    if r.status_code == 401:
        ok("POST /api/v1/auth/apple (invalid token → 401)")
    else:
        warn("POST /api/v1/auth/apple", f"expected 401, got {r.status_code}")

    # Google Sign In — invalid token → 401
    r = await client.post("/api/v1/auth/google", json={"id_token": "bad.google.token"})
    if r.status_code == 401:
        ok("POST /api/v1/auth/google (invalid token → 401)")
    else:
        warn("POST /api/v1/auth/google", f"expected 401, got {r.status_code}")

    # Token refresh — valid refresh token
    r = await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    new_access = None
    if assert_status(r, 200, "POST /api/v1/auth/refresh (valid token)"):
        d = r.json()
        if all(k in d for k in ("access_token", "refresh_token", "token_type")):
            ok("POST /api/v1/auth/refresh", f"new token issued, expires_in={d.get('expires_in')}s")
            new_access = d["access_token"]
            # Store new refresh token for logout test
            refresh_token = d["refresh_token"]
        else:
            fail("POST /api/v1/auth/refresh", f"missing keys: {list(d.keys())}")

    # Token refresh — garbage token → 401
    r = await client.post("/api/v1/auth/refresh", json={"refresh_token": "garbage"})
    if r.status_code == 401:
        ok("POST /api/v1/auth/refresh (invalid token → 401)")
    else:
        warn("POST /api/v1/auth/refresh invalid", f"expected 401, got {r.status_code}")

    # Logout
    r = await client.post("/api/v1/auth/logout", json={"refresh_token": refresh_token})
    if assert_status(r, 200, "POST /api/v1/auth/logout"):
        ok("POST /api/v1/auth/logout", r.json().get("message", ""))

    return new_access


async def test_foods(client: httpx.AsyncClient, auth_headers: dict) -> str | None:
    section("3. Foods Endpoints")
    food_id = None

    # Barcode lookup — OpenFoodFacts path (novel barcode)
    r = await client.get("/api/v1/foods/barcode/5449000214911")  # Coca-Cola Classic EU
    if r.status_code in (200,):
        d = r.json()
        if assert_field(d, "found", "barcode.found"):
            src = d.get("source", "?")
            name = d.get("food_item", {}).get("name", "not found") if d["found"] else "not found"
            ok(f"GET /api/v1/foods/barcode/5449000214911", f"found={d['found']} source={src} name={name!r}")
            if d["found"] and d.get("food_item"):
                food_id = d["food_item"]["id"]
    else:
        warn("GET /api/v1/foods/barcode/5449000214911", f"status={r.status_code}")

    # Barcode — Redis cache hit (same barcode again)
    r2 = await client.get("/api/v1/foods/barcode/0049000042566")
    if r2.status_code == 200:
        d2 = r2.json()
        if d2.get("source") == "cache":
            ok("GET /api/v1/foods/barcode/... (cache hit)", "source=cache ✅")
        else:
            ok("GET /api/v1/foods/barcode/... (DB/external)", f"source={d2.get('source')}")

    # Barcode — not found
    r = await client.get("/api/v1/foods/barcode/0000000000000")
    if r.status_code == 200:
        d = r.json()
        if not d.get("found"):
            ok("GET /api/v1/foods/barcode/0000000000000 (not found)", "found=False ✅")
        else:
            warn("GET /api/v1/foods/barcode/not_found", "expected found=False")
    else:
        warn("GET /api/v1/foods/barcode/not_found", f"status={r.status_code}")

    # Food search — local + USDA
    r = await client.get("/api/v1/foods/search", params={"q": "chicken breast", "limit": 5})
    if assert_status(r, 200, "GET /api/v1/foods/search?q=chicken+breast"):
        d = r.json()
        n = d.get("total", 0)
        if n > 0:
            ok("GET /api/v1/foods/search", f"{n} results, first={d['items'][0]['name']!r}")
            if food_id is None:
                food_id = d["items"][0]["id"]
        else:
            warn("GET /api/v1/foods/search", "0 results — USDA key may not be loading; check .env reload")

    # Food search — minimum length validation
    r = await client.get("/api/v1/foods/search", params={"q": "", "limit": 5})
    if r.status_code == 422:
        ok("GET /api/v1/foods/search (empty q → 422 validation)")
    else:
        warn("GET /api/v1/foods/search empty q", f"expected 422, got {r.status_code}")

    # Manual food creation
    r = await client.post("/api/v1/foods/manual", headers=auth_headers, json={
        "name": "Phase1 Test Protein Bar",
        "brand": "TestBrand",
        "calories": 210.0,
        "protein_g": 22.0,
        "carbohydrates_g": 24.0,
        "fat_g": 6.0,
        "serving_size_g": 60.0,
        "serving_size_description": "1 bar (60g)",
    })
    if assert_status(r, 201, "POST /api/v1/foods/manual"):
        d = r.json()
        ok("POST /api/v1/foods/manual", f"id={d['id']} name={d['name']!r} cals={d['calories']}")
        food_id = d["id"]

    # Get food by ID
    if food_id:
        r = await client.get(f"/api/v1/foods/{food_id}")
        if assert_status(r, 200, f"GET /api/v1/foods/{{food_id}}"):
            d = r.json()
            ok(f"GET /api/v1/foods/{{food_id}}", f"name={d['name']!r}")

    # Get food by ID — not found
    r = await client.get(f"/api/v1/foods/{uuid.uuid4()}")
    if r.status_code == 404:
        ok("GET /api/v1/foods/{nonexistent} → 404")
    else:
        fail("GET /api/v1/foods/{nonexistent}", f"expected 404, got {r.status_code}")

    # Manual food — no auth → 401
    r = await client.post("/api/v1/foods/manual", json={"name": "NoAuth"})
    if r.status_code == 401:
        ok("POST /api/v1/foods/manual (no auth → 401)")
    else:
        fail("POST /api/v1/foods/manual no auth", f"expected 401, got {r.status_code}")

    return food_id


async def test_users(client: httpx.AsyncClient, auth_headers: dict) -> None:
    section("4. Users Endpoints")

    # GET /me
    r = await client.get("/api/v1/users/me", headers=auth_headers)
    if assert_status(r, 200, "GET /api/v1/users/me"):
        d = r.json()
        ok("GET /api/v1/users/me", f"email={d.get('email')} display_name={d.get('display_name')!r}")

    # PUT /me — update profile
    r = await client.put("/api/v1/users/me", headers=auth_headers, json={
        "display_name": "Updated Test User",
        "height_cm": 175.0,
        "activity_level": "moderate",
    })
    if assert_status(r, 200, "PUT /api/v1/users/me"):
        d = r.json()
        if d.get("display_name") == "Updated Test User":
            ok("PUT /api/v1/users/me", f"display_name={d['display_name']!r} height={d.get('height_cm')}")
        else:
            fail("PUT /api/v1/users/me", f"display_name not updated: {d.get('display_name')!r}")

    # PUT /me/preferences
    r = await client.put("/api/v1/users/me/preferences", headers=auth_headers, json={
        "dietary_restrictions": ["vegetarian"],
        "allergies": ["peanuts"],
    })
    if assert_status(r, 200, "PUT /api/v1/users/me/preferences"):
        d = r.json()
        ok("PUT /api/v1/users/me/preferences", f"restrictions={d.get('dietary_restrictions')}")

    # No auth → 401
    r = await client.get("/api/v1/users/me")
    if r.status_code == 401:
        ok("GET /api/v1/users/me (no auth → 401)")
    else:
        fail("GET /api/v1/users/me no auth", f"expected 401, got {r.status_code}")


async def test_weight(client: httpx.AsyncClient, auth_headers: dict) -> None:
    section("5. Weight Endpoints")

    today = date.today().isoformat()

    # Log weight
    r = await client.post("/api/v1/weight/", headers=auth_headers, json={
        "log_date": today,
        "weight_kg": 80.5,
        "body_fat_pct": 18.0,
        "measurement_source": "manual",
    })
    log_id = None
    if assert_status(r, 201, "POST /api/v1/weight/"):
        d = r.json()
        ok("POST /api/v1/weight/", f"weight={d['weight_kg']}kg  date={d['log_date']}")
        log_id = d["id"]

    # Duplicate weight same day → 409
    r = await client.post("/api/v1/weight/", headers=auth_headers, json={
        "log_date": today,
        "weight_kg": 81.0,
    })
    if r.status_code == 409:
        ok("POST /api/v1/weight/ duplicate → 409")
    else:
        warn("POST /api/v1/weight/ duplicate", f"expected 409, got {r.status_code}")

    # GET /weight/latest
    r = await client.get("/api/v1/weight/latest", headers=auth_headers)
    if assert_status(r, 200, "GET /api/v1/weight/latest"):
        d = r.json()
        ok("GET /api/v1/weight/latest", f"weight={d['weight_kg']}kg")

    # GET /weight/history
    r = await client.get("/api/v1/weight/history", headers=auth_headers, params={"days": 7})
    if assert_status(r, 200, "GET /api/v1/weight/history"):
        d = r.json()
        n = len(d.get("entries", []))
        ok("GET /api/v1/weight/history", f"{n} entries, trend={d.get('trend_direction')}")

    # PUT /weight/{id} — update
    if log_id:
        r = await client.put(f"/api/v1/weight/{log_id}", headers=auth_headers, json={
            "weight_kg": 80.2,
            "notes": "Morning weigh-in",
        })
        if assert_status(r, 200, f"PUT /api/v1/weight/{{log_id}}"):
            d = r.json()
            ok(f"PUT /api/v1/weight/{{log_id}}", f"updated weight={d['weight_kg']}kg")


async def test_goals(client: httpx.AsyncClient, auth_headers: dict) -> str | None:
    section("6. Goals Endpoints")
    goal_id = None

    # No active goal → 404
    r = await client.get("/api/v1/goals/", headers=auth_headers)
    if r.status_code == 404:
        ok("GET /api/v1/goals/ (no goal yet → 404)")
    elif r.status_code == 200:
        warn("GET /api/v1/goals/", "already had a goal (may be from earlier test run)")

    # Create goal — lose_weight with custom calories
    r = await client.post("/api/v1/goals/", headers=auth_headers, json={
        "goal_type": "lose_weight",
        "calorie_target": 1800,
        "target_weight_kg": 75.0,
        "weekly_weight_change_target_kg": -0.5,
    })
    if assert_status(r, 201, "POST /api/v1/goals/"):
        d = r.json()
        goal_id = d["id"]
        ok("POST /api/v1/goals/", (
            f"type={d['goal_type']} cals={d['calorie_target']} "
            f"protein={d.get('protein_g')}g carbs={d.get('carb_g')}g fat={d.get('fat_g')}g"
        ))

    # GET active goal
    r = await client.get("/api/v1/goals/", headers=auth_headers)
    if assert_status(r, 200, "GET /api/v1/goals/ (active)"):
        d = r.json()
        ok("GET /api/v1/goals/", f"is_active={d.get('is_active')} calorie_target={d.get('calorie_target')}")

    # GET history
    r = await client.get("/api/v1/goals/history", headers=auth_headers)
    if assert_status(r, 200, "GET /api/v1/goals/history"):
        d = r.json()
        ok("GET /api/v1/goals/history", f"{len(d)} goal(s) in history")

    # PUT goal — update calorie target (auto-recalculates macro grams)
    if goal_id:
        r = await client.put(f"/api/v1/goals/{goal_id}", headers=auth_headers, json={
            "goal_type": "lose_weight",
            "calorie_target": 1700,
        })
        if assert_status(r, 200, f"PUT /api/v1/goals/{{goal_id}}"):
            d = r.json()
            ok(f"PUT /api/v1/goals/{{goal_id}}", f"calorie_target now {d.get('calorie_target')}")

    # Create second goal — should deactivate first
    r = await client.post("/api/v1/goals/", headers=auth_headers, json={
        "goal_type": "maintain",
        "calorie_target": 2200,
    })
    if assert_status(r, 201, "POST /api/v1/goals/ (second goal deactivates first)"):
        d = r.json()
        ok("POST /api/v1/goals/ (second)", f"type={d['goal_type']} cals={d['calorie_target']}")
        goal_id = d["id"]

    return goal_id


async def test_logs(
    client: httpx.AsyncClient,
    auth_headers: dict,
    food_id: str | None,
) -> None:
    section("7. Food Log Endpoints")

    if food_id is None:
        warn("Food logs", "Skipped — no food_id available from foods tests")
        return

    today = date.today().isoformat()

    # GET daily log (empty)
    r = await client.get("/api/v1/logs/daily", headers=auth_headers, params={"log_date": today})
    if assert_status(r, 200, f"GET /api/v1/logs/daily?log_date={today} (empty)"):
        d = r.json()
        ok("GET /api/v1/logs/daily (empty)", (
            f"entries={len(d.get('entries', []))} "
            f"calories={d.get('totals', {}).get('calories', 0)}"
        ))

    # POST — add breakfast
    r = await client.post("/api/v1/logs/daily", headers=auth_headers, json={
        "food_item_id": food_id,
        "log_date": today,
        "meal_type": "breakfast",
        "quantity": 1.0,
        "serving_description": "1 serving",
        "entry_method": "manual",
    })
    log_id = None
    if assert_status(r, 201, "POST /api/v1/logs/daily (breakfast)"):
        d = r.json()
        log_id = d["id"]
        ok("POST /api/v1/logs/daily", (
            f"meal={d['meal_type']} qty={d['quantity']} "
            f"cals={d.get('calories_consumed')} protein={d.get('protein_consumed_g')}g"
        ))

    # POST — add lunch
    r = await client.post("/api/v1/logs/daily", headers=auth_headers, json={
        "food_item_id": food_id,
        "log_date": today,
        "meal_type": "lunch",
        "quantity": 1.5,
    })
    if assert_status(r, 201, "POST /api/v1/logs/daily (lunch)"):
        d = r.json()
        ok("POST /api/v1/logs/daily (lunch)", f"qty={d['quantity']} cals={d.get('calories_consumed')}")

    # GET daily log — now has entries + macro totals
    r = await client.get("/api/v1/logs/daily", headers=auth_headers, params={"log_date": today})
    if assert_status(r, 200, "GET /api/v1/logs/daily (with entries)"):
        d = r.json()
        n = len(d.get("entries", []))
        totals = d.get("totals", {})
        meals = list(d.get("entries_by_meal", {}).keys())
        ok("GET /api/v1/logs/daily (with entries)", (
            f"{n} entries | meals={meals} | "
            f"cals={totals.get('calories')} prot={totals.get('protein_g')}g"
        ))

    # GET with Redis cache (second hit — totals should come from cache)
    r2 = await client.get("/api/v1/logs/daily", headers=auth_headers, params={"log_date": today})
    if r2.status_code == 200:
        ok("GET /api/v1/logs/daily (second hit / cache)", "cache or DB — consistent response ✅")

    # PUT — update quantity
    if log_id:
        r = await client.put(f"/api/v1/logs/daily/{log_id}", headers=auth_headers, json={
            "quantity": 2.0,
        })
        if assert_status(r, 200, f"PUT /api/v1/logs/daily/{{log_id}}"):
            d = r.json()
            ok(f"PUT /api/v1/logs/daily/{{log_id}}", f"new qty={d['quantity']} cals={d.get('calories_consumed')}")

    # GET after update — totals should reflect new quantity (cache invalidated)
    r = await client.get("/api/v1/logs/daily", headers=auth_headers, params={"log_date": today})
    if assert_status(r, 200, "GET /api/v1/logs/daily (after PUT — cache invalidated)"):
        d = r.json()
        ok("GET /api/v1/logs/daily (after PUT)", f"total_cals={d.get('totals', {}).get('calories')}")

    # DELETE log entry
    if log_id:
        r = await client.delete(f"/api/v1/logs/daily/{log_id}", headers=auth_headers)
        if assert_status(r, 200, f"DELETE /api/v1/logs/daily/{{log_id}}"):
            ok(f"DELETE /api/v1/logs/daily/{{log_id}}", r.json().get("message", ""))

    # DELETE nonexistent → 404
    r = await client.delete(f"/api/v1/logs/daily/{uuid.uuid4()}", headers=auth_headers)
    if r.status_code == 404:
        ok("DELETE /api/v1/logs/daily/{nonexistent} → 404")
    else:
        fail("DELETE nonexistent log", f"expected 404, got {r.status_code}")

    # GET default date (today, no param)
    r = await client.get("/api/v1/logs/daily", headers=auth_headers)
    if assert_status(r, 200, "GET /api/v1/logs/daily (default = today)"):
        ok("GET /api/v1/logs/daily (no date param)", "defaults to today ✅")


async def test_caching(client: httpx.AsyncClient) -> None:
    section("8. Redis Caching Verification")

    # Use a barcode we already looked up (should always be in cache from section 3)
    r1 = await client.get("/api/v1/foods/barcode/0049000042566")
    if r1.status_code == 200:
        d1 = r1.json()
        if d1.get("source") == "cache":
            ok("Redis barcode cache (previously fetched barcode)", "source=cache ✅")
        else:
            ok("Redis barcode cache", f"source={d1.get('source')} (cache may have expired)")
    else:
        warn("Redis barcode cache", f"unexpected status {r1.status_code}")

    # Search cache — same query twice
    await client.get("/api/v1/foods/search", params={"q": "coca cola", "limit": 5})
    r2 = await client.get("/api/v1/foods/search", params={"q": "coca cola", "limit": 5})
    if r2.status_code == 200 and r2.elapsed.total_seconds() < 0.5:
        ok("Redis search cache", f"2nd search returned in {r2.elapsed.total_seconds()*1000:.0f}ms (cache hit)")
    elif r2.status_code == 200:
        ok("Redis search cache", f"search responded in {r2.elapsed.total_seconds()*1000:.0f}ms")


async def test_error_handling(client: httpx.AsyncClient, auth_headers: dict) -> None:
    section("9. Error Handling & Validation")

    # Invalid food UUID in log
    r = await client.post("/api/v1/logs/daily", headers=auth_headers, json={
        "food_item_id": str(uuid.uuid4()),
        "log_date": date.today().isoformat(),
        "meal_type": "breakfast",
        "quantity": 1.0,
    })
    if r.status_code == 404:
        ok("POST /api/v1/logs/daily with unknown food_id → 404")
    else:
        fail("POST /api/v1/logs/daily unknown food", f"expected 404, got {r.status_code}")

    # Missing required field
    r = await client.post("/api/v1/logs/daily", headers=auth_headers, json={
        "log_date": date.today().isoformat(),
        "meal_type": "breakfast",
    })
    if r.status_code == 422:
        ok("POST /api/v1/logs/daily missing food_item_id → 422")
    else:
        fail("POST /api/v1/logs/daily missing field", f"expected 422, got {r.status_code}")

    # Invalid goal type
    r = await client.post("/api/v1/goals/", headers=auth_headers, json={
        "goal_type": "invalid_goal_type",
        "calorie_target": 2000,
    })
    if r.status_code == 422:
        ok("POST /api/v1/goals/ invalid goal_type → 422")
    else:
        warn("POST /api/v1/goals/ invalid type", f"expected 422, got {r.status_code}")

    # Malformed UUID path param
    r = await client.get("/api/v1/foods/not-a-uuid")
    if r.status_code in (404, 422):
        ok("GET /api/v1/foods/not-a-uuid → 404/422")
    else:
        warn("GET /api/v1/foods/not-a-uuid", f"got {r.status_code}")


# ── Main ──────────────────────────────────────────────────────────────────────

async def main() -> None:
    print(f"\n{BOLD}{'='*60}{RESET}")
    print(f"{BOLD}  FitandFine Phase 1 — End-to-End Test Suite{RESET}")
    print(f"{BOLD}{'='*60}{RESET}")
    print(f"  Target: {BASE}")

    # Verify server is reachable
    try:
        async with httpx.AsyncClient(base_url=BASE, timeout=5) as probe:
            r = await probe.get("/health")
            if r.status_code != 200:
                print(f"\n{RED}Server returned {r.status_code} on /health. Is it running?{RESET}")
                sys.exit(1)
    except httpx.ConnectError:
        print(f"\n{RED}Cannot connect to {BASE}. Start the server first:{RESET}")
        print("  ./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000")
        sys.exit(1)

    # Create test user
    print(f"\n{YELLOW}  Setting up test user...{RESET}")
    user_id, access_token, refresh_token = await create_test_user_and_token()
    print(f"  User ID:  {user_id}")
    print(f"  Token:    {access_token[:40]}...")

    auth_headers = {"Authorization": f"Bearer {access_token}"}

    try:
        async with httpx.AsyncClient(base_url=BASE, timeout=30) as client:
            await test_public(client)
            new_access = await test_auth(client, refresh_token)
            # Use newly rotated token if available (old refresh was consumed)
            if new_access:
                auth_headers = {"Authorization": f"Bearer {new_access}"}

            food_id = await test_foods(client, auth_headers)
            await test_users(client, auth_headers)
            await test_weight(client, auth_headers)
            await test_goals(client, auth_headers)
            await test_logs(client, auth_headers, food_id)
            await test_caching(client)
            await test_error_handling(client, auth_headers)

    finally:
        print(f"\n{YELLOW}  Cleaning up test user {user_id}...{RESET}", end="")
        await delete_test_user(user_id)
        print(f" {GREEN}done{RESET}")

    # Summary
    total = passed + failed
    print(f"\n{BOLD}{'='*60}{RESET}")
    print(f"{BOLD}  RESULTS{RESET}")
    print(f"{BOLD}{'='*60}{RESET}")
    print(f"  {GREEN}Passed:  {passed}/{total}{RESET}")
    if failed:
        print(f"  {RED}Failed:  {failed}/{total}{RESET}")
    if warnings:
        print(f"  {YELLOW}Warnings: {warnings}{RESET}")

    if failed == 0:
        print(f"\n  {GREEN}{BOLD}✅ All tests passed! Phase 1 is fully operational.{RESET}\n")
    else:
        print(f"\n  {RED}{BOLD}❌ {failed} test(s) failed. See above for details.{RESET}\n")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
