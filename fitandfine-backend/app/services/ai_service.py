"""
Gemini AI service — wraps google-generativeai for use by all agents.

Free tier limits (gemini-2.0-flash):
  - 15 requests/minute
  - 1,000,000 tokens/day
  - 1,500 requests/day

Get your free API key at: https://aistudio.google.com/app/apikey
"""
import json
import logging
from typing import Any, Optional

import google.generativeai as genai
from google.generativeai.types import GenerationConfig

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# Configure once at import time
if settings.gemini_api_key:
    genai.configure(api_key=settings.gemini_api_key)


def _get_model(system_instruction: Optional[str] = None) -> genai.GenerativeModel:
    """Return a configured Gemini model instance."""
    return genai.GenerativeModel(
        model_name=settings.gemini_model,
        system_instruction=system_instruction,
        generation_config=GenerationConfig(
            temperature=0.4,       # Balanced: factual but not robotic
            top_p=0.9,
            max_output_tokens=2048,
        ),
    )


async def generate_text(
    prompt: str,
    system_instruction: Optional[str] = None,
    temperature: float = 0.4,
    max_tokens: int = 2048,
) -> str:
    """
    Single-turn text generation.
    Returns the model's text response.
    Raises RuntimeError on API failure after logging the error.
    """
    if not settings.gemini_api_key:
        raise RuntimeError(
            "GEMINI_API_KEY is not set. "
            "Get a free key at https://aistudio.google.com/app/apikey"
        )

    model = genai.GenerativeModel(
        model_name=settings.gemini_model,
        system_instruction=system_instruction,
        generation_config=GenerationConfig(
            temperature=temperature,
            top_p=0.9,
            max_output_tokens=max_tokens,
        ),
    )

    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as exc:
        logger.error("Gemini API error: %s", exc)
        raise RuntimeError(f"AI generation failed: {exc}") from exc


async def generate_json(
    prompt: str,
    system_instruction: Optional[str] = None,
    temperature: float = 0.2,
) -> dict:
    """
    Generate a response that must be valid JSON.
    Enforces JSON mode via mime_type and retries once on parse failure.
    """
    if not settings.gemini_api_key:
        raise RuntimeError("GEMINI_API_KEY is not set.")

    json_instruction = (
        (system_instruction or "")
        + "\n\nIMPORTANT: Your response must be valid JSON only. "
        "Do not include markdown code fences, explanation text, or any content "
        "outside the JSON object."
    )

    model = genai.GenerativeModel(
        model_name=settings.gemini_model,
        system_instruction=json_instruction,
        generation_config=GenerationConfig(
            temperature=temperature,
            top_p=0.9,
            max_output_tokens=2048,
            response_mime_type="application/json",
        ),
    )

    for attempt in range(2):  # One retry on parse failure
        try:
            response = model.generate_content(prompt)
            text = response.text.strip()
            # Strip markdown fences if the model ignores mime_type hint
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            return json.loads(text)
        except json.JSONDecodeError as exc:
            if attempt == 0:
                logger.warning("Gemini returned invalid JSON (attempt 1), retrying...")
                continue
            logger.error("Gemini returned invalid JSON after retry: %s", exc)
            raise RuntimeError(f"AI returned invalid JSON: {exc}") from exc
        except Exception as exc:
            logger.error("Gemini API error: %s", exc)
            raise RuntimeError(f"AI generation failed: {exc}") from exc


async def chat(
    history: list[dict],
    new_message: str,
    system_instruction: Optional[str] = None,
) -> str:
    """
    Multi-turn chat. history is a list of {"role": "user"|"model", "parts": [str]}.
    Returns the model's reply text.
    """
    if not settings.gemini_api_key:
        raise RuntimeError("GEMINI_API_KEY is not set.")

    model = _get_model(system_instruction)
    chat_session = model.start_chat(history=history)

    try:
        response = chat_session.send_message(new_message)
        return response.text
    except Exception as exc:
        logger.error("Gemini chat error: %s", exc)
        raise RuntimeError(f"AI chat failed: {exc}") from exc
