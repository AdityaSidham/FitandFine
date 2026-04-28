import Foundation

@MainActor
class FoodLogViewModel: ObservableObject {
    @Published var dailyLog: DailyLogResponse? = nil
    @Published var searchResults: [FoodItemResponse] = []
    @Published var isLoading: Bool = false
    @Published var isSearching: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedDate: Date = Date()

    // MARK: - Load Log

    func loadLog() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result: DailyLogResponse = try await NetworkClient.shared.get(
                "/logs/daily?date=\(dateString)"
            )
            dailyLog = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Search Foods

    func searchFoods(query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            // 300ms debounce
            try await Task.sleep(nanoseconds: 300_000_000)

            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let result: FoodSearchResponse = try await NetworkClient.shared.get(
                "/foods/search?q=\(encodedQuery)&limit=20"
            )
            searchResults = result.items
        } catch is CancellationError {
            // Task was cancelled — do nothing
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Add Food Log Entry
    // Named addFoodLog to match references in FoodLogCoordinator.swift

    func addFoodLog(foodItemId: String, mealType: String, quantity: Double) async {
        let request = AddFoodLogRequest(
            foodItemId: foodItemId,
            logDate: dateString,
            logTime: nil,
            mealType: mealType,
            quantity: quantity,
            servingDescription: nil,
            entryMethod: "manual",
            notes: nil
        )
        do {
            let _: FoodLogEntryResponse = try await NetworkClient.shared.post(
                "/logs/daily",
                body: request
            )
            await loadLog()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Entry

    func deleteEntry(logId: String) async {
        do {
            let _: MessageResponse = try await NetworkClient.shared.delete(
                "/logs/daily/\(logId)"
            )
            await loadLog()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    var entriesByMeal: [String: [FoodLogEntryResponse]] {
        dailyLog?.entriesByMeal ?? [:]
    }

    var mealTypes: [String] {
        let allMeals = ["breakfast", "lunch", "dinner", "snack"]
        let meals = entriesByMeal
        return allMeals.filter { !(meals[$0]?.isEmpty ?? true) }
    }
}
