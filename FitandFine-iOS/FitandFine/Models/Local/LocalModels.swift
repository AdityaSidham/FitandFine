import Foundation
import SwiftData

@Model
final class CachedFoodItem {
    @Attribute(.unique) var id: String
    var name: String
    var brand: String?
    var barcode: String?
    var source: String
    var servingSizeG: Double?
    var servingSizeDescription: String?
    var calories: Double?
    var proteinG: Double?
    var carbohydratesG: Double?
    var fatG: Double?
    var fiberG: Double?
    var isVerified: Bool
    var cachedAt: Date

    init(from response: FoodItemResponse) {
        self.id = response.id
        self.name = response.name
        self.brand = response.brand
        self.barcode = response.barcode
        self.source = response.source
        self.servingSizeG = response.servingSizeG
        self.servingSizeDescription = response.servingSizeDescription
        self.calories = response.calories
        self.proteinG = response.proteinG
        self.carbohydratesG = response.carbohydratesG
        self.fatG = response.fatG
        self.fiberG = response.fiberG
        self.isVerified = response.isVerified
        self.cachedAt = Date()
    }
}

@Model
final class LocalDailyLog {
    @Attribute(.unique) var id: String
    var foodItemId: String
    var foodItemName: String
    var logDate: String
    var logTime: Date
    var mealType: String
    var quantity: Double
    var caloriesConsumed: Double
    var proteinConsumedG: Double
    var carbsConsumedG: Double
    var fatConsumedG: Double
    var entryMethod: String
    var syncStatus: String

    init(
        id: String = UUID().uuidString,
        foodItemId: String,
        foodItemName: String,
        logDate: String,
        logTime: Date = Date(),
        mealType: String,
        quantity: Double,
        caloriesConsumed: Double,
        proteinConsumedG: Double,
        carbsConsumedG: Double,
        fatConsumedG: Double,
        entryMethod: String = "manual",
        syncStatus: String = "pendingSync"
    ) {
        self.id = id
        self.foodItemId = foodItemId
        self.foodItemName = foodItemName
        self.logDate = logDate
        self.logTime = logTime
        self.mealType = mealType
        self.quantity = quantity
        self.caloriesConsumed = caloriesConsumed
        self.proteinConsumedG = proteinConsumedG
        self.carbsConsumedG = carbsConsumedG
        self.fatConsumedG = fatConsumedG
        self.entryMethod = entryMethod
        self.syncStatus = syncStatus
    }
}

@Model
final class CachedUserProfile {
    @Attribute(.unique) var id: String
    var displayName: String?
    var email: String?
    var heightCm: Double?
    var activityLevel: String?
    var timezone: String
    var cachedAt: Date

    init(from response: UserResponse) {
        self.id = response.id
        self.displayName = response.displayName
        self.email = response.email
        self.heightCm = response.heightCm
        self.activityLevel = response.activityLevel
        self.timezone = response.timezone
        self.cachedAt = Date()
    }
}

@Model
final class CachedGoal {
    @Attribute(.unique) var id: String
    var goalType: String
    var calorieTarget: Int?
    var proteinG: Double?
    var carbG: Double?
    var fatG: Double?
    var isActive: Bool
    var cachedAt: Date

    init(from response: GoalResponse) {
        self.id = response.id
        self.goalType = response.goalType
        self.calorieTarget = response.calorieTarget
        self.proteinG = response.proteinG
        self.carbG = response.carbG
        self.fatG = response.fatG
        self.isActive = response.isActive
        self.cachedAt = Date()
    }
}
