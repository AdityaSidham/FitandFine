import Foundation

// MARK: - Auth
struct AppleSignInRequest: Codable {
    let identityToken: String
    let userIdentifier: String
    let displayName: String?
    let email: String?
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

// MARK: - User
struct UserResponse: Codable, Identifiable {
    let id: String
    let email: String?
    let displayName: String?
    let dateOfBirth: String?
    let sex: String?
    let heightCm: Double?
    let activityLevel: String?
    let timezone: String
    let dietaryRestrictions: [String]?
    let allergies: [String]?
    let budgetPerMealUsd: Double?
    let createdAt: String
}

struct UserProfileUpdate: Codable {
    let displayName: String?
    let dateOfBirth: String?
    let sex: String?
    let heightCm: Double?
    let activityLevel: String?
    let timezone: String?
}

// MARK: - Food
struct FoodItemResponse: Codable, Identifiable {
    let id: String
    let name: String
    let brand: String?
    let barcode: String?
    let source: String
    let servingSizeG: Double?
    let servingSizeDescription: String?
    let calories: Double?
    let proteinG: Double?
    let carbohydratesG: Double?
    let fatG: Double?
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?
    let allergenFlags: [String]?
    let isVerified: Bool
}

struct BarcodeLookupResponse: Codable {
    let found: Bool
    let foodItem: FoodItemResponse?
    let source: String?
}

struct FoodSearchResponse: Codable {
    let items: [FoodItemResponse]
    let total: Int
    let query: String
}

struct FoodItemCreate: Codable {
    let name: String
    let brand: String?
    let servingSizeG: Double?
    let servingSizeDescription: String?
    let calories: Double?
    let proteinG: Double?
    let carbohydratesG: Double?
    let fatG: Double?
    let allergenFlags: [String]?
}

// MARK: - Food Log
struct AddFoodLogRequest: Codable {
    let foodItemId: String
    let logDate: String
    let logTime: String?
    let mealType: String
    let quantity: Double
    let servingDescription: String?
    let entryMethod: String?
    let notes: String?
}

struct FoodLogEntryResponse: Codable, Identifiable {
    let id: String
    let foodItemId: String
    // foodItem is fetched separately via GET /foods/{foodItemId} when needed
    let logDate: String
    let logTime: String
    let mealType: String
    let quantity: Double
    let caloriesConsumed: Double
    let proteinConsumedG: Double
    let carbsConsumedG: Double
    let fatConsumedG: Double
    let entryMethod: String?
    let notes: String?
    let createdAt: String
}

struct DailyMacroTotals: Codable {
    let date: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let entriesCount: Int
}

struct DailyLogResponse: Codable {
    let date: String
    let totals: DailyMacroTotals
    let goalCalories: Double?
    let goalProteinG: Double?
    let goalCarbsG: Double?
    let goalFatG: Double?
    let entries: [FoodLogEntryResponse]
    let entriesByMeal: [String: [FoodLogEntryResponse]]
}

// MARK: - Goals
struct GoalResponse: Codable, Identifiable {
    let id: String
    let goalType: String
    let targetWeightKg: Double?
    let calorieTarget: Int?
    let proteinPct: Double?
    let carbPct: Double?
    let fatPct: Double?
    let proteinG: Double?
    let carbG: Double?
    let fatG: Double?
    let isActive: Bool
    let createdAt: String
}

struct CreateGoalRequest: Codable {
    let goalType: String
    let targetWeightKg: Double?
    let weeklyWeightChangeTargetKg: Double?
    let calorieTarget: Int?
}

// MARK: - Weight
struct AddWeightLogRequest: Codable {
    let logDate: String
    let weightKg: Double
    let bodyFatPct: Double?
    let measurementSource: String?
}

struct WeightLogResponse: Codable, Identifiable {
    let id: String
    let logDate: String
    let logTime: String
    let weightKg: Double
    let bodyFatPct: Double?
    let measurementSource: String?
    let createdAt: String
}

struct WeightHistoryResponse: Codable {
    let entries: [WeightLogResponse]
    let currentWeightKg: Double?
    let startingWeightKg: Double?
    let totalChangeKg: Double?
    let weeklyRateKg: Double?
    let trendDirection: String?
}

// MARK: - Scan (Phase 2)

struct LabelScanResponse: Codable {
    let scanId: String
    let food: ScannedFoodItem
    let confidence: Double
    let message: String
}

struct ScannedFoodItem: Codable {
    let name: String
    let brand: String?
    let servingSizeG: Double?
    let servingSizeDescription: String?
    let calories: Double?
    let proteinG: Double?
    let carbohydratesG: Double?
    let fatG: Double?
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?
    let saturatedFatG: Double?
    let allergenFlags: [String]?
    let ingredientsText: String?
}

struct ConfirmScanRequest: Codable {
    let scanId: String?
    let food: ScannedFoodItem
}

struct ConfirmScanResponse: Codable {
    let foodItemId: String
    let message: String
}

struct BarcodeScanResult: Codable {
    let found: Bool
    let foodItem: FoodItemResponse?
    let source: String?
}

// MARK: - AI / Coach (Phase 3)

struct CoachMessageRequest: Codable {
    let message: String
    let sessionId: String?
}

struct CoachSSEChunk: Codable {
    let text: String?
    let done: Bool?
    let error: String?
}

struct WeeklyFinding: Codable, Identifiable {
    var id: String { title }
    let category: String
    let severity: String          // info | warning | critical
    let title: String
    let description: String
    let recommendation: String
}

struct WeeklyReportResponse: Codable {
    let summary: String
    let findings: [WeeklyFinding]
    let adherenceScore: Double
    let periodStart: String
    let periodEnd: String
    let generatedAt: String
    let dataDays: Int
    let estimatedDailyDeficit: Double?
}

// MARK: - Phase 4 — Progress Evaluation

struct GoalAdjustmentProposal: Codable {
    let action: String              // no_change | reduce_calories | increase_calories
    let calorieDelta: Int
    let newCalorieTarget: Int
    let reasoning: String
    let confidence: Double
}

struct ProgressEvaluationResponse: Codable {
    let progressStatus: String      // on_track | plateau | insufficient_data | off_track
    let plateauDetected: Bool
    let plateauType: String?
    let weeksEvaluated: Int
    let weightReadings: Int
    let avgWeeklyChangeKg: Double?
    let expectedWeeklyChangeKg: Double?
    let adjustment: GoalAdjustmentProposal
    let narrative: String
    let generatedAt: String
}

// MARK: - Phase 4 — Recommendations

struct MealIngredient: Codable, Identifiable {
    var id: String { name }
    let name: String
    let quantity: String
}

struct MealRecommendation: Codable, Identifiable {
    let id = UUID()
    let mealName: String
    let mealType: String
    let prepTimeMinutes: Int?
    let ingredients: [MealIngredient]
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let reasoning: String

    enum CodingKeys: String, CodingKey {
        case mealName, mealType, prepTimeMinutes, ingredients
        case calories, proteinG, carbsG, fatG, reasoning
    }
}

struct RecommendationsResponse: Codable {
    let recommendations: [MealRecommendation]
    let remainingCalories: Double
    let remainingProteinG: Double
    let remainingCarbsG: Double
    let remainingFatG: Double
    let macroFitScore: Double
    let generatedAt: String
}

struct ApplyAdjustmentRequest: Codable {
    let newCalorieTarget: Int
    let goalId: String
}

// MARK: - Phase 5 — Preferences & Analytics

struct UserPreferencesUpdate: Codable {
    let dietaryRestrictions: [String]?
    let allergies: [String]?
    let preferredCuisine: [String]?
    let budgetPerMealUsd: Double?
}

struct DailyMacroSummary: Codable, Identifiable {
    var id: String { date }
    let date: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let entriesCount: Int
}

struct LogAnalyticsResponse: Codable {
    let dailyTotals: [DailyMacroSummary]
    let loggedDays: Int
    let totalDays: Int
    let avgCalories: Double
    let avgProteinG: Double
    let avgCarbsG: Double
    let avgFatG: Double
}

// MARK: - Generic API response wrapper
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
}

struct MessageResponse: Codable {
    let message: String
}
