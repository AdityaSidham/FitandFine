import SwiftUI

struct FoodResultCard: View {
    let food: FoodItemResponse
    var onAddToLog: (String, Double) -> Void

    @State private var selectedMealType: String = "lunch"
    @State private var quantity: Double = 1.0

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]
    private let mealIcons = [
        "breakfast": "sunrise.fill",
        "lunch":     "sun.max.fill",
        "dinner":    "moon.stars.fill",
        "snack":     "leaf.fill"
    ]
    private let mealColors: [String: Color] = [
        "breakfast": .orange,
        "lunch":     DS.Color.accent,
        "dinner":    .purple,
        "snack":     .blue
    ]

    private var adjustedCalories: Double { (food.calories          ?? 0) * quantity }
    private var adjustedProtein:  Double { (food.proteinG          ?? 0) * quantity }
    private var adjustedCarbs:    Double { (food.carbohydratesG    ?? 0) * quantity }
    private var adjustedFat:      Double { (food.fatG              ?? 0) * quantity }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // ── Header ───────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                Text(food.name)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let brand = food.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if let serving = food.servingSizeDescription {
                        PillLabel(text: serving, color: .secondary, size: .caption)
                    } else if let g = food.servingSizeG {
                        PillLabel(text: "\(Int(g))g/serving", color: .secondary, size: .caption)
                    }
                    if food.isVerified {
                        PillLabel(text: "✓ Verified", color: .blue, size: .caption)
                    }
                }
            }

            // ── Macro grid ───────────────────────────────────────────────
            HStack(spacing: 0) {
                macroCell("Calories", adjustedCalories, "kcal", DS.Color.accent)
                Divider().frame(height: 44)
                macroCell("Protein",  adjustedProtein,  "g",    DS.Color.protein)
                Divider().frame(height: 44)
                macroCell("Carbs",    adjustedCarbs,    "g",    DS.Color.carbs)
                Divider().frame(height: 44)
                macroCell("Fat",      adjustedFat,      "g",    DS.Color.fat)
            }
            .background(Color(.systemGray5).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            // ── Quantity stepper ─────────────────────────────────────────
            HStack {
                Text("Servings")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 14) {
                    Button {
                        Haptics.select()
                        if quantity > 0.25 { quantity = max(0.25, quantity - 0.25) }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(quantity > 0.25 ? DS.Color.accent : Color(.tertiaryLabel))
                    }
                    .disabled(quantity <= 0.25)

                    Text(String(format: quantity.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2g", quantity))
                        .font(.headline.monospacedDigit())
                        .frame(minWidth: 36)
                        .contentTransition(.numericText())
                        .animation(DS.Anim.springFast, value: quantity)

                    Button {
                        Haptics.select()
                        quantity += 0.25
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(DS.Color.accent)
                    }
                }
            }

            // ── Meal picker ──────────────────────────────────────────────
            HStack(spacing: 8) {
                ForEach(mealTypes, id: \.self) { meal in
                    let isSelected = selectedMealType == meal
                    let color = mealColors[meal] ?? DS.Color.accent

                    Button {
                        Haptics.select()
                        withAnimation(DS.Anim.springFast) { selectedMealType = meal }
                    } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? color : Color(.systemGray5))
                                    .frame(width: 40, height: 40)
                                Image(systemName: mealIcons[meal] ?? "fork.knife")
                                    .font(.subheadline)
                                    .foregroundStyle(isSelected ? .white : .secondary)
                            }
                            Text(meal.capitalized)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected ? color : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(isSelected ? color.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Add button ───────────────────────────────────────────────
            Button {
                Haptics.medium()
                onAddToLog(selectedMealType, quantity)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to Log")
                }
            }
            .buttonStyle(.green)
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .shadow(color: DS.Shadow.lifted.color, radius: DS.Shadow.lifted.radius, y: DS.Shadow.lifted.y)
    }

    private func macroCell(_ label: String, _ value: Double, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(String(format: "%.0f", value))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(DS.Anim.springFast, value: value)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
