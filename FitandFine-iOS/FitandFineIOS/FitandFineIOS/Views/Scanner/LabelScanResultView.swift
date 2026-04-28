import SwiftUI

// MARK: - Label Scan Result View
// Shows Gemini-parsed nutrition. User can edit values before confirming.

struct LabelScanResultView: View {
    @ObservedObject var viewModel: ScannerViewModel
    let onAddToLog: (String, String) -> Void  // (mealType, foodItemId)
    @Environment(\.dismiss) private var dismiss

    // Editable fields — pre-filled from scan result
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var fiber: String = ""
    @State private var sodium: String = ""
    @State private var servingDesc: String = ""
    @State private var selectedMeal: String = "lunch"

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    var body: some View {
        NavigationStack {
            Form {
                // ── Confidence banner ────────────────────────────────────
                if let result = viewModel.labelScanResult {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: confidenceIcon(result.confidence))
                                .foregroundStyle(confidenceColor(result.confidence))
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.message)
                                    .font(.subheadline)
                                Text("Tap any field to edit before saving")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── Product info ─────────────────────────────────────────
                Section("Product") {
                    LabeledContent("Name") {
                        TextField("Food name", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Brand") {
                        TextField("Brand (optional)", text: $brand)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Serving") {
                        TextField("e.g. 1 cup (240g)", text: $servingDesc)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // ── Nutrition facts ──────────────────────────────────────
                Section("Nutrition per Serving") {
                    nutrientRow(label: "Calories", value: $calories, unit: "kcal")
                    nutrientRow(label: "Protein",  value: $protein,  unit: "g")
                    nutrientRow(label: "Carbs",    value: $carbs,    unit: "g")
                    nutrientRow(label: "Fat",      value: $fat,      unit: "g")
                    nutrientRow(label: "Fiber",    value: $fiber,    unit: "g")
                    nutrientRow(label: "Sodium",   value: $sodium,   unit: "mg")
                }

                // ── Meal type ────────────────────────────────────────────
                Section("Add to Meal") {
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(mealTypes, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                // ── Actions ──────────────────────────────────────────────
                Section {
                    Button {
                        Task { await confirmAndAdd() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isUploading {
                                ProgressView().tint(.white)
                            } else {
                                Label("Add to Log", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.green)
                    .disabled(viewModel.isUploading || name.isEmpty)
                }
            }
            .navigationTitle("Nutrition Label")
            .navigationBarTitleDisplayMode(.inline)
            .tint(DS.Color.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { prefill() }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Prefill from scan result

    private func prefill() {
        guard let food = viewModel.labelScanResult?.food else { return }
        name       = food.name
        brand      = food.brand ?? ""
        calories   = food.calories.map { String(Int($0)) } ?? ""
        protein    = food.proteinG.map { String(format: "%.1f", $0) } ?? ""
        carbs      = food.carbohydratesG.map { String(format: "%.1f", $0) } ?? ""
        fat        = food.fatG.map { String(format: "%.1f", $0) } ?? ""
        fiber      = food.fiberG.map { String(format: "%.1f", $0) } ?? ""
        sodium     = food.sodiumMg.map { String(Int($0)) } ?? ""
        servingDesc = food.servingSizeDescription ?? ""
        selectedMeal = viewModel.selectedMealType
    }

    // MARK: - Confirm & add to log

    private func confirmAndAdd() async {
        let edited = ScannedFoodItem(
            name: name,
            brand: brand.isEmpty ? nil : brand,
            servingSizeG: nil,
            servingSizeDescription: servingDesc.isEmpty ? nil : servingDesc,
            calories: Double(calories),
            proteinG: Double(protein),
            carbohydratesG: Double(carbs),
            fatG: Double(fat),
            fiberG: Double(fiber),
            sugarG: nil,
            sodiumMg: Double(sodium),
            saturatedFatG: nil,
            allergenFlags: viewModel.labelScanResult?.food.allergenFlags,
            ingredientsText: viewModel.labelScanResult?.food.ingredientsText
        )

        guard let foodItemId = await viewModel.confirmLabelScan(editedFood: edited) else { return }
        let success = await viewModel.addConfirmedFoodToLog(foodItemId: foodItemId)
        if success {
            onAddToLog(selectedMeal, foodItemId)
            dismiss()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func nutrientRow(label: String, value: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
        }
    }

    private func confidenceIcon(_ c: Double) -> String {
        if c >= 0.9 { return "checkmark.seal.fill" }
        if c >= 0.7 { return "exclamationmark.triangle.fill" }
        return "xmark.octagon.fill"
    }

    private func confidenceColor(_ c: Double) -> Color {
        if c >= 0.9 { return .green }
        if c >= 0.7 { return .orange }
        return .red
    }
}
