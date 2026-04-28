import SwiftUI

struct FoodResultCard: View {
    let food: FoodItemResponse
    var onAddToLog: (String, Double) -> Void

    @State private var selectedMealType: String = "lunch"
    @State private var quantity: Double = 1.0

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    private var adjustedCalories: Double { (food.calories ?? 0) * quantity }
    private var adjustedProtein: Double { (food.proteinG ?? 0) * quantity }
    private var adjustedCarbs: Double { (food.carbohydratesG ?? 0) * quantity }
    private var adjustedFat: Double { (food.fatG ?? 0) * quantity }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                    .lineLimit(2)
                if let brand = food.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let serving = food.servingSizeDescription {
                    Text("Serving: \(serving)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Macro grid
            HStack {
                MacroCell(label: "Calories", value: adjustedCalories, unit: "kcal", color: .green)
                MacroCell(label: "Protein", value: adjustedProtein, unit: "g", color: .blue)
                MacroCell(label: "Carbs", value: adjustedCarbs, unit: "g", color: .orange)
                MacroCell(label: "Fat", value: adjustedFat, unit: "g", color: .red)
            }

            Divider()

            // Quantity stepper
            HStack {
                Text("Quantity")
                    .font(.subheadline)
                Spacer()
                Stepper(value: $quantity, in: 0.25...10.0, step: 0.25) {
                    Text(String(format: "%.2g", quantity))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            // Meal type picker
            Picker("Meal", selection: $selectedMealType) {
                ForEach(mealTypes, id: \.self) { type in
                    Text(type.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Add button
            Button {
                onAddToLog(selectedMealType, quantity)
            } label: {
                Text("Add to Log")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct MacroCell: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.0f", value))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
