import Foundation
import Combine

// MARK: - Scan Mode

enum ScanMode {
    case barcode       // AVFoundation barcode reader
    case nutritionLabel // Photo → Gemini Vision
}

// MARK: - ScannerViewModel

@MainActor
class ScannerViewModel: ObservableObject {
    // Barcode result
    @Published var scannedFood: FoodItemResponse? = nil

    // Label scan result
    @Published var labelScanResult: LabelScanResponse? = nil
    @Published var confirmedFoodItemId: String? = nil

    // Shared state
    @Published var isSearching: Bool = false
    @Published var isUploading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedMealType: String = "lunch"
    @Published var quantity: Double = 1.0
    @Published var mode: ScanMode = .barcode

    // MARK: - Barcode Lookup

    func lookupBarcode(_ barcode: String) async {
        guard !isSearching else { return }
        isSearching = true
        defer { isSearching = false }

        do {
            let result: BarcodeScanResult = try await NetworkClient.shared.get(
                "/scan/barcode/\(barcode)"
            )
            if result.found {
                scannedFood = result.foodItem
            } else {
                errorMessage = "Barcode '\(barcode)' not found in our database.\nTry scanning the nutrition label instead."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Nutrition Label Scan (Phase 2)

    func scanNutritionLabel(imageData: Data, mimeType: String = "image/jpeg") async {
        guard !isUploading else { return }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        do {
            let result: LabelScanResponse = try await NetworkClient.shared.uploadImage(
                "/scan/label",
                imageData: imageData,
                mimeType: mimeType,
                fieldName: "file"
            )
            labelScanResult = result
        } catch NetworkError.serverError(let code, _) where code == 429 {
            errorMessage = "Gemini API quota exhausted.\n\nFix: Get a new free key at aistudio.google.com/app/apikey and update GEMINI_API_KEY in your backend .env file."
        } catch {
            errorMessage = "Label scan failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Confirm Scanned Label → Save to DB

    func confirmLabelScan(editedFood: ScannedFoodItem? = nil) async -> String? {
        guard let result = labelScanResult else { return nil }
        isUploading = true
        defer { isUploading = false }

        let foodToSave = editedFood ?? result.food
        let request = ConfirmScanRequest(scanId: result.scanId, food: foodToSave)

        do {
            let response: ConfirmScanResponse = try await NetworkClient.shared.post(
                "/scan/confirm",
                body: request
            )
            confirmedFoodItemId = response.foodItemId
            return response.foodItemId
        } catch {
            errorMessage = "Could not save food: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Add Barcode Food to Log

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

    // MARK: - Add Confirmed Label Food to Log

    func addConfirmedFoodToLog(foodItemId: String) async -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        let request = AddFoodLogRequest(
            foodItemId: foodItemId,
            logDate: today,
            logTime: nil,
            mealType: selectedMealType,
            quantity: quantity,
            servingDescription: nil,
            entryMethod: "label_scan",
            notes: nil
        )

        do {
            let _: FoodLogEntryResponse = try await NetworkClient.shared.post(
                "/logs/daily",
                body: request
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Reset

    func reset() {
        scannedFood = nil
        labelScanResult = nil
        confirmedFoodItemId = nil
        errorMessage = nil
        quantity = 1.0
    }
}
