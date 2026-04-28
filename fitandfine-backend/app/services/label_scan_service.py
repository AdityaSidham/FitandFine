"""
Phase 2 — Nutrition Label Scanner Service
==========================================
Uses Gemini Vision (gemini-2.0-flash multimodal) to extract structured
nutrition data from photos of food labels or packaged products.

Architecture decision: Gemini Vision replaces Tesseract as the primary
extractor because it handles rotated/glare-affected labels far better.
Tesseract remains available as an offline fallback (see _ocr_fallback).

Free-tier limits (gemini-2.0-flash as of 2026):
  15 req/min · 1M tokens/day · 1500 req/day
"""
import asyncio
import io
import json
import logging
from typing import Optional

import PIL.Image
import google.generativeai as genai
from google.generativeai.types import GenerationConfig

from app.config import Settings
from app.schemas.food import FoodItemCreate
from app.schemas.scan import LabelScanResult

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Gemini Vision prompt
# ---------------------------------------------------------------------------

_SYSTEM = (
    "You are an expert nutrition label reader. "
    "Extract data precisely from what is visible — never guess or hallucinate values. "
    "Return ONLY a valid JSON object with no markdown, no explanation."
)

_PROMPT = """\
Analyze this image of a food product or nutrition facts label.

Return a JSON object with EXACTLY these fields (use null for values you cannot read):
{
  "name": "product name — required, use 'Unknown Food' if not visible",
  "brand": "brand/manufacturer name or null",
  "serving_size_g": serving weight in grams as a number or null,
  "serving_size_description": "e.g. '1 cup (240g)' as string or null",
  "calories": calories per serving as number or null,
  "protein_g": protein in grams per serving or null,
  "carbohydrates_g": total carbohydrates in grams per serving or null,
  "fat_g": total fat in grams per serving or null,
  "fiber_g": dietary fiber in grams per serving or null,
  "sugar_g": total sugars in grams per serving or null,
  "sodium_mg": sodium in MILLIGRAMS per serving or null,
  "saturated_fat_g": saturated fat in grams per serving or null,
  "allergen_flags": ["MILK","WHEAT","EGGS","SOY","NUTS","PEANUTS","FISH","SHELLFISH"] — \
include only those visible in the 'Contains:' section or bold ingredients, empty array [] if none,
  "ingredients_text": "full ingredients list as one string or null",
  "confidence": 0.95
}

confidence scoring:
  0.90–1.00 = clear, well-lit label
  0.70–0.89 = partially visible or slight blur
  0.50–0.69 = poor lighting or heavily cropped
  < 0.50    = label barely readable

If this image is NOT a food product or label, return: {"error": "not_a_food_label"}
Return ONLY the JSON object — no markdown fences, no text outside the JSON.
"""


class LabelScanService:
    """Nutrition label scanner using Gemini Vision."""

    MAX_IMAGE_DIM = 1280   # pixels — larger costs more tokens
    MAX_FILE_MB   = 10

    def __init__(self, settings: Settings):
        self.settings = settings
        if settings.gemini_api_key:
            genai.configure(api_key=settings.gemini_api_key)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def parse_nutrition_label(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
    ) -> LabelScanResult:
        """
        Accept raw image bytes, call Gemini Vision, return LabelScanResult.
        Raises ValueError for bad input, RuntimeError for API failure.
        """
        if not self.settings.gemini_api_key:
            raise ValueError(
                "GEMINI_API_KEY is not configured. "
                "Get a free key at https://aistudio.google.com/app/apikey "
                "and add it to your .env file."
            )

        image = self._prepare_image(image_bytes)
        raw_json = await self._call_gemini(image)
        return self._parse_response(raw_json)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _prepare_image(self, image_bytes: bytes) -> PIL.Image.Image:
        try:
            img = PIL.Image.open(io.BytesIO(image_bytes))
        except Exception as exc:
            raise ValueError(f"Cannot open image: {exc}") from exc

        # Convert HEIC/HEIF or unusual modes to RGB for Gemini
        if img.mode not in ("RGB", "L"):
            img = img.convert("RGB")

        # Resize to reduce token usage
        w, h = img.size
        if max(w, h) > self.MAX_IMAGE_DIM:
            scale = self.MAX_IMAGE_DIM / max(w, h)
            img = img.resize((int(w * scale), int(h * scale)), PIL.Image.LANCZOS)

        return img

    async def _call_gemini(self, image: PIL.Image.Image) -> str:
        """Run blocking Gemini call in thread pool to keep FastAPI async."""
        model = genai.GenerativeModel(
            model_name=self.settings.gemini_model,
            system_instruction=_SYSTEM,
            generation_config=GenerationConfig(
                temperature=0.05,          # Very low — factual extraction
                top_p=0.9,
                max_output_tokens=1024,
                response_mime_type="application/json",
            ),
        )
        try:
            response = await asyncio.to_thread(
                model.generate_content, [_PROMPT, image]
            )
            return response.text.strip()
        except Exception as exc:
            logger.error("Gemini Vision API error: %s", exc)
            raise RuntimeError(f"Gemini API call failed: {exc}") from exc

    def _parse_response(self, raw_text: str) -> LabelScanResult:
        """Parse Gemini's JSON response into a LabelScanResult."""
        # Strip markdown code fences if model ignores mime_type hint
        text = raw_text
        if text.startswith("```"):
            parts = text.split("```")
            text = parts[1] if len(parts) >= 2 else text
            if text.startswith("json"):
                text = text[4:]
        text = text.strip()

        try:
            data = json.loads(text)
        except json.JSONDecodeError as exc:
            logger.error("Gemini non-JSON response (first 300 chars): %s", raw_text[:300])
            raise RuntimeError(f"AI returned invalid JSON: {exc}") from exc

        if "error" in data:
            raise ValueError(f"Image rejected: {data['error']}")

        confidence = float(data.pop("confidence", 0.5))
        confidence = max(0.0, min(1.0, confidence))

        food = FoodItemCreate(
            name=data.get("name") or "Scanned Food",
            brand=_str_or_none(data.get("brand")),
            serving_size_g=_to_float(data.get("serving_size_g")),
            serving_size_description=_str_or_none(data.get("serving_size_description")),
            calories=_to_float(data.get("calories")),
            protein_g=_to_float(data.get("protein_g")),
            carbohydrates_g=_to_float(data.get("carbohydrates_g")),
            fat_g=_to_float(data.get("fat_g")),
            fiber_g=_to_float(data.get("fiber_g")),
            sugar_g=_to_float(data.get("sugar_g")),
            sodium_mg=_to_float(data.get("sodium_mg")),
            saturated_fat_g=_to_float(data.get("saturated_fat_g")),
            allergen_flags=data.get("allergen_flags") or [],
            ingredients_text=_str_or_none(data.get("ingredients_text")),
        )

        return LabelScanResult(food=food, confidence=confidence)


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def _to_float(value) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _str_or_none(value) -> Optional[str]:
    if not value or str(value).strip() in ("null", "None", ""):
        return None
    return str(value).strip()
