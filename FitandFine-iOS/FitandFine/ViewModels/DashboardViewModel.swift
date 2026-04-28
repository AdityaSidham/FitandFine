import Foundation

struct DashboardData {
    let dailyLog: DailyLogResponse
    let activeGoal: GoalResponse?
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var state: ViewState<DashboardData> = .idle
    @Published var selectedDate: Date = Date()

    // MARK: - Load

    func loadDashboard() async {
        state = .loading

        do {
            async let logResult: DailyLogResponse = NetworkClient.shared.get(
                "/logs/daily?date=\(dateString)"
            )
            async let goalResult: GoalResponse? = try? NetworkClient.shared.get("/goals/current")

            let (dailyLog, activeGoal) = try await (logResult, goalResult)
            let data = DashboardData(dailyLog: dailyLog, activeGoal: activeGoal)
            state = .loaded(data)
        } catch {
            state = .error(error.localizedDescription)
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
