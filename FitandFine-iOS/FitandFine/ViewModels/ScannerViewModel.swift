import Foundation

@MainActor
class ScannerViewModel: ObservableObject {
    @Published var scannedFood: FoodItemResponse? = nil
    @Published var isSearching: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedMealType: String = "lunch"
    @Published var quantity: Double = 1.0

    // MARK: - Barcode Lookup

    func lookupBarcode(_ barcode: String) async {
        guard !isSearching else { return }
        isSearching = true
        defer { isSearching = false }

        do {
            let result: BarcodeLookupResponse = try await NetworkClient.shared.get(
                "/foods/barcode/\(barcode)"
            )
            if result.found {
                scannedFood = result.foodItem
            } else {
                errorMessage = "Food not found in database"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Add to Log
    // Returns (mealType, foodItemId) on success for the coordinator callback,
    // or nil on failure.

    func addToLog() async -> (String, String)? {
        guard let food = scannedFood else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        let request = AddFoodLogRequest(
            foodItemId: food.id,
            logDate: today,
            logTime: nil,
            mealType: selectedMealType,
            quantity: quantity,
            servingDescription: food.servingSizeDescription,
            entryMethod: "barcode",
            notes: nil
        )

        do {
            let _: FoodLogEntryResponse = try await NetworkClient.shared.post(
                "/logs/daily",
                body: request
            )
            return (selectedMealType, food.id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Reset

    func reset() {
        scannedFood = nil
        errorMessage = nil
        quantity = 1.0
    }
}
