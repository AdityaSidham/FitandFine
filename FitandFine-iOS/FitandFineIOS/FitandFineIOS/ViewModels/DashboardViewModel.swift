import Foundation
import Combine

struct DashboardData {
    let dailyLog: DailyLogResponse
    let activeGoal: GoalResponse?
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var state: ViewState<DashboardData> = .idle
    @Published var selectedDate: Date = Date()
    @Published var foodNames: [String: String] = [:]

    // Streak & history (populated separately so dashboard doesn't block on them)
    @Published var currentStreak: Int = 0
    @Published var last7Days: [DailyMacroSummary] = []   // for StreakCard dots

    // MARK: - Load

    func loadDashboard() async {
        state = .loading

        do {
            async let logResult: DailyLogResponse = NetworkClient.shared.get(
                "/logs/daily?date=\(dateString)"
            )
            async let goalResult: GoalResponse? = try? NetworkClient.shared.get("/goals/")

            let (dailyLog, activeGoal) = try await (logResult, goalResult)
            let data = DashboardData(dailyLog: dailyLog, activeGoal: activeGoal)
            state = .loaded(data)

            // Fetch food names for entries shown on dashboard
            let ids = Set(dailyLog.entries.map { $0.foodItemId })
            await fetchFoodNames(for: ids)
        } catch {
            state = .error(error.localizedDescription)
        }

        // Fetch streak in parallel (non-blocking — failure is silent)
        Task { await loadStreak() }
    }

    // MARK: - Streak

    private func loadStreak() async {
        let analytics: LogAnalyticsResponse? = try? await NetworkClient.shared.get("/logs/analytics?days=30")
        guard let totals = analytics?.dailyTotals else { return }

        // Keep last 7 calendar days for the chain dots
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let sorted = totals.sorted { $0.date < $1.date }

        // Build a dict for quick lookup
        var byDate: [String: DailyMacroSummary] = [:]
        for t in sorted { byDate[t.date] = t }

        // Compute 7-day window ending today
        var sevenDays: [DailyMacroSummary] = []
        for offset in (0..<7).reversed() {
            if let d = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) {
                let key = formatter.string(from: d)
                let entry = byDate[key] ?? DailyMacroSummary(
                    date: key, calories: 0, proteinG: 0, carbsG: 0, fatG: 0, entriesCount: 0
                )
                sevenDays.append(entry)
            }
        }
        last7Days = sevenDays

        // Compute streak: count consecutive logged days going backwards from yesterday
        // (today is still in-progress so doesn't break the chain)
        currentStreak = computeStreak(byDate: byDate, formatter: formatter)
    }

    private func computeStreak(byDate: [String: DailyMacroSummary], formatter: DateFormatter) -> Int {
        var streak = 0
        var checkDate = Date()
        let todayKey = formatter.string(from: checkDate)

        // If today already has entries, count it
        if let todayEntry = byDate[todayKey], todayEntry.entriesCount > 0 {
            streak += 1
        }
        // Walk backwards
        for i in 1...30 {
            guard let d = Calendar.current.date(byAdding: .day, value: -i, to: Date()) else { break }
            let key = formatter.string(from: d)
            if let entry = byDate[key], entry.entriesCount > 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Food names

    private func fetchFoodNames(for ids: Set<String>) async {
        let uncached = ids.filter { foodNames[$0] == nil }
        guard !uncached.isEmpty else { return }
        await withTaskGroup(of: (String, String?).self) { group in
            for id in uncached {
                group.addTask {
                    let food: FoodItemResponse? = try? await NetworkClient.shared.get("/foods/\(id)")
                    return (id, food?.name)
                }
            }
            for await (id, name) in group {
                if let name { foodNames[id] = name }
            }
        }
    }

    // MARK: - Computed: Calories

    var caloriesConsumed: Double {
        state.value?.dailyLog.totals.calories ?? 0
    }

    var caloriesTarget: Double {
        state.value?.activeGoal.map { Double($0.calorieTarget ?? 2000) } ?? 2000
    }

    var caloriesRemaining: Double {
        max(0, caloriesTarget - caloriesConsumed)
    }

    var calorieProgress: Double {
        min(1.0, caloriesConsumed / max(1, caloriesTarget))
    }

    // MARK: - Computed: Protein

    var proteinConsumed: Double {
        state.value?.dailyLog.totals.proteinG ?? 0
    }

    var proteinTarget: Double {
        state.value?.activeGoal?.proteinG ?? 150
    }

    var proteinRemaining: Double {
        max(0, proteinTarget - proteinConsumed)
    }

    // MARK: - Computed: Carbs

    var carbsConsumed: Double {
        state.value?.dailyLog.totals.carbsG ?? 0
    }

    var carbsTarget: Double {
        state.value?.activeGoal?.carbG ?? 200
    }

    var carbsRemaining: Double {
        max(0, carbsTarget - carbsConsumed)
    }

    // MARK: - Computed: Fat

    var fatConsumed: Double {
        state.value?.dailyLog.totals.fatG ?? 0
    }

    var fatTarget: Double {
        state.value?.activeGoal?.fatG ?? 65
    }

    var fatRemaining: Double {
        max(0, fatTarget - fatConsumed)
    }

    // MARK: - Helper

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }
}
