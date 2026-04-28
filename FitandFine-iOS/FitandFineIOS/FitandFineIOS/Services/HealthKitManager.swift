import Foundation
import HealthKit
import Combine

// MARK: - Sleep Stages

struct SleepStages {
    let totalHours: Double   // deep + rem + core
    let deepHours: Double
    let remHours: Double
    let coreHours: Double
    let awakeHours: Double

    static let empty = SleepStages(totalHours: 0, deepHours: 0, remHours: 0,
                                   coreHours: 0, awakeHours: 0)

    /// 0-100 sleep quality score
    var score: Int {
        guard totalHours > 0 else { return 0 }
        // Base score from total hours (7–9 hrs = 100)
        let hoursScore: Double
        switch totalHours {
        case 8...:      hoursScore = 100
        case 7..<8:     hoursScore = 90 + (totalHours - 7) * 10
        case 6..<7:     hoursScore = 70 + (totalHours - 6) * 20
        case 5..<6:     hoursScore = 45 + (totalHours - 5) * 25
        default:        hoursScore = max(0, totalHours / 5 * 45)
        }
        // Bonus for deep + REM (restorative sleep)
        let restorativeRatio = totalHours > 0 ? (deepHours + remHours) / totalHours : 0
        let qualityBonus = restorativeRatio * 10
        return min(100, Int(hoursScore + qualityBonus))
    }

    var label: String {
        switch score {
        case 85...: return "Excellent"
        case 70..<85: return "Good"
        case 55..<70: return "Fair"
        case 40..<55: return "Poor"
        default:      return "Very Short"
        }
    }
}

// MARK: - HealthKit Manager

@MainActor
final class HealthKitManager: ObservableObject {

    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    // MARK: - Published state

    @Published var isAuthorized = false
    @Published var authorizationDenied = false

    // Activity
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Double = 0

    // Body mass
    @Published var latestWeightKg: Double? = nil

    // Sleep
    @Published var lastNightSleep: SleepStages = .empty

    // MARK: - Availability

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {}

    // MARK: - HK Types

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        let quantityIds: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .bodyMass,
        ]
        quantityIds
            .compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
            .forEach { types.insert($0) }

        // Sleep analysis (category type)
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }

        return types
    }

    private var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        let ids: [HKQuantityTypeIdentifier] = [
            .bodyMass, .dietaryEnergyConsumed, .dietaryProtein,
            .dietaryCarbohydrates, .dietaryFatTotal, .dietaryFiber, .dietarySodium,
        ]
        ids.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
           .forEach { types.insert($0) }
        return types
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard Self.isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            await refreshAll()
        } catch {
            authorizationDenied = true
        }
    }

    // MARK: - Refresh all

    func refreshAll() async {
        async let steps    = fetchTodaySteps()
        async let calories = fetchTodayActiveCalories()
        async let weight   = fetchLatestWeight()
        async let sleep    = fetchLastNightSleep()

        todaySteps          = await steps
        todayActiveCalories = await calories
        latestWeightKg      = await weight
        lastNightSleep      = await sleep
    }

    // MARK: - READ: Steps

    func fetchTodaySteps() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(), options: .strictStartDate
        )
        return await withCheckedContinuation { cont in
            store.execute(HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                cont.resume(returning: Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
            })
        }
    }

    // MARK: - READ: Active Calories

    func fetchTodayActiveCalories() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(), options: .strictStartDate
        )
        return await withCheckedContinuation { cont in
            store.execute(HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                cont.resume(returning: result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
            })
        }
    }

    // MARK: - READ: Latest weight

    func fetchLatestWeight() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            store.execute(HKSampleQuery(
                sampleType: type, predicate: nil, limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                cont.resume(returning: kg)
            })
        }
    }

    // MARK: - READ: Weight history

    func fetchWeightHistory(days: Int) async -> [(date: Date, kg: Double)] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        return await withCheckedContinuation { cont in
            store.execute(HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let results = (samples as? [HKQuantitySample] ?? []).map {
                    (date: $0.endDate, kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                }
                cont.resume(returning: results)
            })
        }
    }

    // MARK: - READ: Last night's sleep

    func fetchLastNightSleep() async -> SleepStages {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return .empty
        }

        // Window: yesterday 6 PM → today noon  (captures full overnight sleep)
        let cal = Calendar.current
        let now = Date()
        guard
            let windowStart = cal.date(bySettingHour: 18, minute: 0, second: 0,
                                       of: cal.date(byAdding: .day, value: -1, to: now)!),
            let windowEnd   = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now)
        else { return .empty }

        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart, end: windowEnd, options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { cont in
            store.execute(HKSampleQuery(
                sampleType: type, predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    cont.resume(returning: .empty)
                    return
                }

                var deepSecs:  TimeInterval = 0
                var remSecs:   TimeInterval = 0
                var coreSecs:  TimeInterval = 0
                var awakeSecs: TimeInterval = 0

                for s in categorySamples {
                    let dur = s.endDate.timeIntervalSince(s.startDate)
                    switch s.value {
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deepSecs  += dur
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        remSecs   += dur
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        coreSecs  += dur
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        coreSecs  += dur   // treat unspecified as core
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        awakeSecs += dur
                    default:
                        break
                    }
                }

                cont.resume(returning: SleepStages(
                    totalHours: (deepSecs + remSecs + coreSecs) / 3600,
                    deepHours:  deepSecs  / 3600,
                    remHours:   remSecs   / 3600,
                    coreHours:  coreSecs  / 3600,
                    awakeHours: awakeSecs / 3600
                ))
            })
        }
    }

    // MARK: - WRITE: Body mass

    func writeWeight(kg: Double, date: Date = Date()) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date, end: date
        )
        try await store.save(sample)
        latestWeightKg = kg
    }

    // MARK: - WRITE: Nutrition

    struct NutritionData {
        let calories: Double
        let proteinG: Double
        let carbsG: Double
        let fatG: Double
        let fiberG: Double?
        let sodiumMg: Double?
        let foodName: String
        let date: Date
    }

    func writeNutrition(_ data: NutritionData) async throws {
        var samples: [HKQuantitySample] = []
        let metadata: [String: Any] = [HKMetadataKeyFoodType: data.foodName]

        func sample(_ id: HKQuantityTypeIdentifier, value: Double, unit: HKUnit) -> HKQuantitySample? {
            guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
            return HKQuantitySample(type: type,
                                    quantity: HKQuantity(unit: unit, doubleValue: value),
                                    start: data.date, end: data.date,
                                    metadata: metadata)
        }

        if let s = sample(.dietaryEnergyConsumed, value: data.calories,  unit: .kilocalorie()) { samples.append(s) }
        if let s = sample(.dietaryProtein,         value: data.proteinG,  unit: .gram())        { samples.append(s) }
        if let s = sample(.dietaryCarbohydrates,   value: data.carbsG,    unit: .gram())        { samples.append(s) }
        if let s = sample(.dietaryFatTotal,        value: data.fatG,      unit: .gram())        { samples.append(s) }
        if let fiber  = data.fiberG,
           let s = sample(.dietaryFiber,           value: fiber,          unit: .gram())        { samples.append(s) }
        if let sodium = data.sodiumMg,
           let s = sample(.dietarySodium,          value: sodium / 1000,  unit: .gram())        { samples.append(s) }

        guard !samples.isEmpty else { return }
        try await store.save(samples)
    }

    // MARK: - Authorization helpers

    func authorizationStatus(for id: HKQuantityTypeIdentifier) -> HKAuthorizationStatus {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return .notDetermined }
        return store.authorizationStatus(for: type)
    }

    var hasRequestedAuthorization: Bool {
        guard Self.isAvailable else { return false }
        return authorizationStatus(for: .stepCount) != .notDetermined
    }
}
