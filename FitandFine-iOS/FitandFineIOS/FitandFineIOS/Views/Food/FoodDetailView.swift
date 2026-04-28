import SwiftUI
import Combine

// MARK: - FoodDetailView

struct FoodDetailView: View {
    let foodId: String
    let onDismiss: () -> Void

    @StateObject private var vm = FoodDetailViewModel()
    @EnvironmentObject private var healthKit: HealthKitManager
    @State private var quantity: Double = 1.0
    @State private var selectedMeal = "lunch"
    @State private var isAdding = false
    @State private var addError: String? = nil
    @State private var showSuccess = false

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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if vm.isLoading {
                    loadingState
                } else if let food = vm.food {
                    foodContent(food)
                } else if let err = vm.errorMessage {
                    ErrorView(message: err) {
                        Task { await vm.load(foodId: foodId) }
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("Food Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(foodId: foodId) }
        .overlay(successToast)
    }

    // MARK: - Food content

    @ViewBuilder
    private func foodContent(_ food: FoodItemResponse) -> some View {
        // Header card
        VStack(alignment: .leading, spacing: 10) {
            Text(food.name)
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)

            if let brand = food.brand {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if let serving = food.servingSizeDescription {
                    PillLabel(text: serving, color: .secondary, size: .caption)
                } else if let servingG = food.servingSizeG {
                    PillLabel(text: "\(Int(servingG))g / serving", color: .secondary, size: .caption)
                }
                if food.isVerified {
                    PillLabel(text: "✓ Verified", color: .blue, size: .caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(16)
        .entranceAnimation(delay: 0.0)

        // Nutrition card
        NutritionCard(food: food, quantity: quantity)
            .entranceAnimation(delay: 0.05)

        // Quantity stepper
        quantityCard
            .entranceAnimation(delay: 0.10)

        // Meal picker
        mealPickerCard
            .entranceAnimation(delay: 0.13)

        // Error
        if let err = addError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, 4)
        }

        // Add to Log button
        Button {
            Haptics.medium()
            Task { await addToLog(food: food) }
        } label: {
            HStack(spacing: 8) {
                if isAdding {
                    ProgressView().tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to Log")
                }
            }
        }
        .buttonStyle(.green)
        .disabled(isAdding)
        .entranceAnimation(delay: 0.16)
    }

    // MARK: - Quantity stepper

    private var quantityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Servings")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            HStack(spacing: 0) {
                // Minus
                Button {
                    Haptics.select()
                    if quantity > 0.5 { quantity = (quantity * 10 - 5).rounded() / 10 }
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.semibold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(quantity > 0.5 ? DS.Color.accent : Color(.tertiaryLabel))
                }
                .disabled(quantity <= 0.5)

                Divider().frame(height: 28)

                // Display
                VStack(spacing: 2) {
                    Text(String(format: quantity.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", quantity))
                        .font(.title2.bold().monospacedDigit())
                        .contentTransition(.numericText())
                        .animation(DS.Anim.springFast, value: quantity)
                    Text("serving\(quantity == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 28)

                // Plus
                Button {
                    Haptics.select()
                    quantity = (quantity * 10 + 5).rounded() / 10
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(DS.Color.accent)
                }
            }
            .background(Color(.systemGray5).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        }
        .appCard(16)
    }

    // MARK: - Meal picker

    private var mealPickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add to Meal")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            HStack(spacing: 8) {
                ForEach(mealTypes, id: \.self) { meal in
                    let isSelected = selectedMeal == meal
                    let color = mealColors[meal] ?? DS.Color.accent

                    Button {
                        Haptics.select()
                        withAnimation(DS.Anim.springFast) { selectedMeal = meal }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? color : Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                Image(systemName: mealIcons[meal] ?? "fork.knife")
                                    .font(.body)
                                    .foregroundStyle(isSelected ? .white : .secondary)
                            }
                            Text(meal.capitalized)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected ? color : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? color.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .stroke(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .appCard(16)
    }

    // MARK: - Loading state

    private var loadingState: some View {
        VStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(height: i == 1 ? 130 : 80)
                    .shimmer()
            }
        }
    }

    // MARK: - Success toast

    private var successToast: some View {
        VStack {
            Spacer()
            if showSuccess {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Color.accent)
                        .font(.body.weight(.semibold))
                    Text("Added to \(selectedMeal.capitalized)!")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(.bottom, 36)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DS.Anim.spring, value: showSuccess)
    }

    // MARK: - Add to log

    private func addToLog(food: FoodItemResponse) async {
        isAdding = true
        addError = nil
        defer { isAdding = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        let request = AddFoodLogRequest(
            foodItemId: food.id,
            logDate: today,
            logTime: nil,
            mealType: selectedMeal,
            quantity: quantity,
            servingDescription: food.servingSizeDescription,
            entryMethod: "manual",
            notes: nil
        )

        do {
            let _: FoodLogEntryResponse = try await NetworkClient.shared.post("/logs/daily", body: request)

            Task {
                let nutrition = HealthKitManager.NutritionData(
                    calories:  (food.calories   ?? 0) * quantity,
                    proteinG:  (food.proteinG   ?? 0) * quantity,
                    carbsG:    (food.carbohydratesG ?? 0) * quantity,
                    fatG:      (food.fatG        ?? 0) * quantity,
                    fiberG:    food.fiberG.map { $0 * quantity },
                    sodiumMg:  food.sodiumMg.map { $0 * quantity },
                    foodName:  food.name,
                    date:      Date()
                )
                try? await healthKit.writeNutrition(nutrition)
            }

            Haptics.success()
            withAnimation(DS.Anim.spring) { showSuccess = true }
            try? await Task.sleep(nanoseconds: 900_000_000)
            onDismiss()
        } catch {
            Haptics.warning()
            addError = error.localizedDescription
        }
    }
}

// MARK: - Nutrition Card

private struct NutritionCard: View {
    let food: FoodItemResponse
    let quantity: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Calorie hero
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(calorieLabel)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(DS.Anim.springFast, value: quantity)
                Text("kcal")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(servingLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 16)

            // Macro row
            if food.proteinG != nil || food.carbohydratesG != nil || food.fatG != nil {
                HStack(spacing: 0) {
                    macroCell("Protein", food.proteinG, DS.Color.protein)
                    macroCell("Carbs",   food.carbohydratesG, DS.Color.carbs)
                    macroCell("Fat",     food.fatG, DS.Color.fat)
                }
                .background(Color(.systemGray5).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            } else {
                Text("Nutrition details not available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }

            // Secondary nutrients
            let extras: [(String, Double?, String)] = [
                ("Fiber",  food.fiberG,  "g"),
                ("Sugar",  food.sugarG,  "g"),
                ("Sodium", food.sodiumMg, "mg"),
            ]
            let available = extras.filter { $0.1 != nil }
            if !available.isEmpty {
                Divider().padding(.top, 14)
                HStack(spacing: 0) {
                    ForEach(available, id: \.0) { item in
                        VStack(spacing: 3) {
                            Text(formatted(item.1, scale: quantity))
                                .font(.subheadline.bold().monospacedDigit())
                                .contentTransition(.numericText())
                                .animation(DS.Anim.springFast, value: quantity)
                            Text("\(item.0) \(item.2)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 12)
            }
        }
        .appCard(16)
    }

    @ViewBuilder
    private func macroCell(_ label: String, _ value: Double?, _ color: Color) -> some View {
        VStack(spacing: 5) {
            Text(formatted(value, scale: quantity))
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(DS.Anim.springFast, value: quantity)
            Text("\(label) g")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var calorieLabel: String {
        guard let cal = food.calories else { return "—" }
        return "\(Int((cal * quantity).rounded()))"
    }

    private var servingLabel: String {
        quantity == 1 ? "1 serving" : "\(String(format: quantity.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", quantity)) servings"
    }

    private func formatted(_ value: Double?, scale: Double) -> String {
        guard let v = value else { return "—" }
        let scaled = v * scale
        return scaled >= 10 ? "\(Int(scaled.rounded()))" : String(format: "%.1f", scaled)
    }
}

// MARK: - ViewModel

@MainActor
class FoodDetailViewModel: ObservableObject {
    @Published var food: FoodItemResponse? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func load(foodId: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            food = try await NetworkClient.shared.get("/foods/\(foodId)")
        } catch NetworkError.notFound {
            errorMessage = "This food item could not be found."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
