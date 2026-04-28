from datetime import date
from typing import Optional


ACTIVITY_MULTIPLIERS = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "very_active": 1.9,
}

DEFAULT_MACRO_SPLITS = {
    "lose_weight":  {"protein_pct": 35.0, "carb_pct": 40.0, "fat_pct": 25.0},
    "maintain":     {"protein_pct": 30.0, "carb_pct": 45.0, "fat_pct": 25.0},
    "gain_muscle":  {"protein_pct": 35.0, "carb_pct": 45.0, "fat_pct": 20.0},
    "recomp":       {"protein_pct": 40.0, "carb_pct": 35.0, "fat_pct": 25.0},
}

GOAL_DEFICITS = {
    "lose_weight": -500,
    "maintain": 0,
    "gain_muscle": 250,
    "recomp": -250,
}


def calculate_bmr(
    weight_kg: float,
    height_cm: float,
    age_years: int,
    sex: str,
) -> float:
    """Mifflin-St Jeor equation — best validated for general population."""
    bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age_years
    if sex.lower() in ("male", "m"):
        return bmr + 5
    else:
        return bmr - 161


def calculate_tdee(bmr: float, activity_level: str) -> float:
    multiplier = ACTIVITY_MULTIPLIERS.get(activity_level, 1.55)
    return bmr * multiplier


def calculate_calorie_target(tdee: float, goal_type: str) -> int:
    delta = GOAL_DEFICITS.get(goal_type, 0)
    target = tdee + delta
    # Safety floor: never below 1200 kcal/day
    return max(int(target), 1200)


def calculate_macro_grams(
    calorie_target: int,
    protein_pct: float,
    carb_pct: float,
    fat_pct: float,
) -> dict[str, float]:
    protein_g = round((calorie_target * protein_pct / 100) / 4, 1)
    carb_g = round((calorie_target * carb_pct / 100) / 4, 1)
    fat_g = round((calorie_target * fat_pct / 100) / 9, 1)
    return {"protein_g": protein_g, "carb_g": carb_g, "fat_g": fat_g}


def get_default_macro_split(goal_type: str) -> dict[str, float]:
    return DEFAULT_MACRO_SPLITS.get(goal_type, DEFAULT_MACRO_SPLITS["maintain"])


def age_from_dob(dob: date) -> int:
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def compute_goal_targets(
    weight_kg: float,
    height_cm: float,
    date_of_birth: date,
    sex: str,
    activity_level: str,
    goal_type: str,
    custom_protein_pct: Optional[float] = None,
    custom_carb_pct: Optional[float] = None,
    custom_fat_pct: Optional[float] = None,
) -> dict:
    """Full pipeline: user profile → calorie + macro targets."""
    age = age_from_dob(date_of_birth)
    bmr = calculate_bmr(weight_kg, height_cm, age, sex)
    tdee = calculate_tdee(bmr, activity_level)
    calorie_target = calculate_calorie_target(tdee, goal_type)

    if custom_protein_pct and custom_carb_pct and custom_fat_pct:
        macro_split = {
            "protein_pct": custom_protein_pct,
            "carb_pct": custom_carb_pct,
            "fat_pct": custom_fat_pct,
        }
    else:
        macro_split = get_default_macro_split(goal_type)

    macros = calculate_macro_grams(
        calorie_target,
        macro_split["protein_pct"],
        macro_split["carb_pct"],
        macro_split["fat_pct"],
    )

    return {
        "bmr": round(bmr, 1),
        "tdee": round(tdee, 1),
        "calorie_target": calorie_target,
        **macro_split,
        **macros,
    }
