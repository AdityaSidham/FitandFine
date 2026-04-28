import SwiftUI

// MARK: - Recommendation Section

struct RecommendationSection: View {
    @StateObject private var vm = RecommendationViewModel()
    @State private var expanded: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Complete Your Macros", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button {
                    Haptics.light()
                    Task { await vm.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DS.Color.accent)
                        .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                        .animation(
                            vm.isLoading
                                ? .linear(duration: 0.7).repeatForever(autoreverses: false)
                                : .default,
                            value: vm.isLoading
                        )
                }
                .disabled(vm.isLoading)
            }
            .padding(.horizontal)

            if vm.isLoading {
                // Shimmer placeholders
                VStack(spacing: 10) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(Color(.systemGray5))
                            .frame(height: 76)
                            .shimmer()
                    }
                }
                .padding(.horizontal)

            } else if let recs = vm.recommendations {
                RemainingBar(recs: recs)
                    .padding(.horizontal)

                ForEach(recs.recommendations) { meal in
                    MealCard(meal: meal, isExpanded: expanded == meal.mealName) {
                        Haptics.select()
                        withAnimation(DS.Anim.spring) {
                            expanded = expanded == meal.mealName ? nil : meal.mealName
                        }
                    }
                    .padding(.horizontal)
                }
            } else if vm.errorMessage != nil {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.secondary)
                    Text("Couldn't load recommendations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .task { await vm.load() }
    }
}

// MARK: - Remaining Macro Bar

private struct RemainingBar: View {
    let recs: RecommendationsResponse

    var body: some View {
        HStack(spacing: 0) {
            remainingCell("Left",    recs.remainingCalories, "kcal", DS.Color.accent)
            Divider().frame(height: 36)
            remainingCell("Protein", recs.remainingProteinG, "g",    DS.Color.protein)
            Divider().frame(height: 36)
            remainingCell("Carbs",   recs.remainingCarbsG,  "g",    DS.Color.carbs)
            Divider().frame(height: 36)
            remainingCell("Fat",     recs.remainingFatG,    "g",    DS.Color.fat)
        }
        .padding(.vertical, 10)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)
    }

    private func remainingCell(_ label: String, _ value: Double, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(Int(max(0, value)))")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Meal Card

private struct MealCard: View {
    let meal: MealRecommendation
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button(action: onTap) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(mealColor.opacity(0.14))
                            .frame(width: 46, height: 46)
                        Image(systemName: mealIcon)
                            .foregroundStyle(mealColor)
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.mealName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            PillLabel(text: "\(Int(meal.calories)) kcal", color: DS.Color.accent, size: .caption2)
                            if let prep = meal.prepTimeMinutes {
                                PillLabel(text: "\(prep) min", color: .secondary, size: .caption2)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        macroChip("P", Int(meal.proteinG), DS.Color.protein)
                        macroChip("C", Int(meal.carbsG),   DS.Color.carbs)
                        macroChip("F", Int(meal.fatG),     DS.Color.fat)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 2)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 12) {
                    if !meal.ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ingredients")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.3)
                            ForEach(meal.ingredients) { ing in
                                HStack {
                                    Circle()
                                        .fill(DS.Color.accent)
                                        .frame(width: 5, height: 5)
                                    Text(ing.name)
                                        .font(.caption)
                                    Spacer()
                                    Text(ing.quantity)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                            .padding(.top, 1)
                        Text(meal.reasoning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)
    }

    private func macroChip(_ letter: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 2) {
            Text(letter).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text("\(value)g").font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    private var mealColor: Color {
        switch meal.mealType {
        case "breakfast": return .orange
        case "lunch":     return DS.Color.accent
        case "dinner":    return .purple
        default:          return .blue
        }
    }

    private var mealIcon: String {
        switch meal.mealType {
        case "breakfast": return "sunrise.fill"
        case "lunch":     return "sun.max.fill"
        case "dinner":    return "moon.stars.fill"
        default:          return "leaf.fill"
        }
    }
}
