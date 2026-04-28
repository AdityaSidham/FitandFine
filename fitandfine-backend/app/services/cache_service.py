import json
from typing import Any, Optional

import redis.asyncio as aioredis

# TTL constants (in seconds)
TTL_SESSION = 7 * 24 * 3600       # 7 days
TTL_FOOD_BARCODE = 72 * 3600      # 72 hours
TTL_EXTERNAL_API = 7 * 24 * 3600  # 7 days
TTL_DAILY_MACROS = 25 * 3600      # 25 hours
TTL_FOOD_SEARCH = 6 * 3600        # 6 hours
TTL_AI_RECOMMENDATIONS = 4 * 3600 # 4 hours
TTL_WEEKLY_ANALYSIS = 8 * 24 * 3600 # 8 days


class CacheService:
    def __init__(self, redis: aioredis.Redis):
        self.redis = redis

    # --- Food Barcode ---
    async def get_food_by_barcode(self, barcode: str) -> Optional[dict]:
        key = f"food:barcode:{barcode}"
        data = await self.redis.get(key)
        return json.loads(data) if data else None

    async def set_food_by_barcode(self, barcode: str, food_data: dict) -> None:
        key = f"food:barcode:{barcode}"
        await self.redis.setex(key, TTL_FOOD_BARCODE, json.dumps(food_data, default=str))

    # --- External API responses ---
    async def get_usda_response(self, fdc_id: str) -> Optional[dict]:
        key = f"ext:usda:{fdc_id}"
        data = await self.redis.get(key)
        return json.loads(data) if data else None

    async def set_usda_response(self, fdc_id: str, data: dict) -> None:
        key = f"ext:usda:{fdc_id}"
        await self.redis.setex(key, TTL_EXTERNAL_API, json.dumps(data, default=str))

    async def get_off_response(self, product_code: str) -> Optional[dict]:
        key = f"ext:off:{product_code}"
        data = await self.redis.get(key)
        return json.loads(data) if data else None

    async def set_off_response(self, product_code: str, data: dict) -> None:
        key = f"ext:off:{product_code}"
        await self.redis.setex(key, TTL_EXTERNAL_API, json.dumps(data, default=str))

    # --- Daily macro totals ---
    async def get_daily_macros(self, user_id: str, date_str: str) -> Optional[dict]:
        key = f"macros:daily:{user_id}:{date_str}"
        data = await self.redis.get(key)
        return json.loads(data) if data else None

    async def set_daily_macros(self, user_id: str, date_str: str, totals: dict) -> None:
        key = f"macros:daily:{user_id}:{date_str}"
        await self.redis.setex(key, TTL_DAILY_MACROS, json.dumps(totals, default=str))

    async def invalidate_daily_macros(self, user_id: str, date_str: str) -> None:
        key = f"macros:daily:{user_id}:{date_str}"
        await self.redis.delete(key)

    # --- Food search ---
    async def get_food_search(self, query_hash: str) -> Optional[list]:
        key = f"search:foods:{query_hash}"
        data = await self.redis.get(key)
        return json.loads(data) if data else None

    async def set_food_search(self, query_hash: str, results: list) -> None:
        key = f"search:foods:{query_hash}"
        await self.redis.setex(key, TTL_FOOD_SEARCH, json.dumps(results, default=str))

    # --- Session / JWT ---
    async def blacklist_token(self, jti: str, ttl: int) -> None:
        key = f"blacklist:{jti}"
        await self.redis.setex(key, ttl, "1")

    async def is_token_blacklisted(self, jti: str) -> bool:
        key = f"blacklist:{jti}"
        return bool(await self.redis.get(key))

    async def store_refresh_token(self, user_id: str, jti: str, ttl_seconds: int = TTL_SESSION) -> None:
        key = f"refresh:{user_id}:{jti}"
        await self.redis.setex(key, ttl_seconds, "1")

    async def revoke_refresh_token(self, user_id: str, jti: str) -> None:
        key = f"refresh:{user_id}:{jti}"
        await self.redis.delete(key)

    async def is_refresh_token_valid(self, user_id: str, jti: str) -> bool:
        key = f"refresh:{user_id}:{jti}"
        return bool(await self.redis.get(key))

    # Alias used by the auth router
    async def validate_refresh_token(self, user_id: str, jti: str) -> bool:
        return await self.is_refresh_token_valid(user_id, jti)

    # --- Rate limiting ---
    async def check_rate_limit(
        self, key: str, limit: int, window_seconds: int
    ) -> tuple[bool, int]:
        """Returns (is_allowed, current_count)."""
        current = await self.redis.incr(key)
        if current == 1:
            await self.redis.expire(key, window_seconds)
        return current <= limit, current
