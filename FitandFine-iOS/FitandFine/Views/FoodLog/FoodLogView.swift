import SwiftUI

// MARK: - FoodLogView

struct FoodLogView: View {
    @StateObject private var viewModel = FoodLogViewModel()
    var coordinator: FoodLogCoordinator

    private let allMealTypes = ["breakfast", "lunch", "dinner", "snack"]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ffWarmWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                dateStrip

                if viewModel.isLoading {
                    LoadingView(message: "Loading log...")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            ForEach(allMealTypes, id: \.self) { meal in
                                MealSectionCard(
                                    meal: meal,
                                    entries: viewModel.entriesByMeal[meal] ?? [],
                                    onDelete: { entry in
                                        Task { await viewModel.deleteEntry(logId: entry.id) }
                                    },
                                    onAdd: { coordinator.navigate(to: .addFood) }
                                )
                            }
                        }
                        .padding(.horizontal, DS.paddingPage)
                        .padding(.top, 14)
                        .padding(.bottom, 100)
                    }
                }
            }

            if let totals = viewModel.dailyLog?.totals {
                DailyTotalBar(totals: totals)
            }
        }
        .navigationTitle("Food Log")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadLog() }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task { await viewModel.loadLog() }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Date Strip

    @ViewBuilder
    private var dateStrip: some View {
        HStack {
            Button {
                viewModel.selectedDate = Calendar.current.date(
                    byAdding: .day, value: -1, to: viewModel.selectedDate
                ) ?? viewModel.selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ffSage)
                    .frame(width: 34, height: 34)
                    .background(Color.ffMintLight)
                    .clipShape(Circle())
            }

            Spacer()

            Text(viewModel.selectedDate, style: .date)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ffText1)

            Spacer()

            Button {
                viewModel.selectedDate = Calendar.current.date(
                    byAdding: .day, value: 1, to: viewModel.selectedDate
                ) ?? viewModel.selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ffSage)
                    .frame(width: 34, height: 34)
                    .background(Color.ffMintLight)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, DS.paddingPage)
        .padding(.vertical, 11)
        .background(Color.white)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

// MARK: - Meal Section Card

private struct MealSectionCard: View {
    let meal: String
    let entries: [FoodLogEntryResponse]
    let onDelete: (FoodLogEntryResponse) -> Void
    let onAdd: () -> Void

    private var mealColor: Color {
        switch meal {
        case "breakfast": return Color(red: 0.96, green: 0.72, blue: 0.30)
        case "lunch":     return Color.ffSage
        case "dinner":    return Color.ffTeal
        default:          return Color.ffProtein
        }
    }

    private var mealIcon: String {
        switch meal {
        case "breakfast": return "sunrise.fill"
        case "lunch":     return "sun.max.fill"
        case "dinner":    return "moon.stars.fill"
        default:          return "star.fill"
        }
    }

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.caloriesConsumed }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(mealColor.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: mealIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(mealColor)
                }
                Text(meal.capitalized)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                Spacer()
                if !entries.isEmpty {
                    Text("\(Int(totalCalories)) kcal")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ffText2)
                }
            }
            .padding(.horizontal, DS.paddingCard)
            .padding(.top, DS.paddingCard)
            .padding(.bottom, entries.isEmpty ? 4 : 10)

            if !entries.isEmpty {
                Divider().padding(.horizontal, DS.paddingCard)

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    FoodLogRowView(entry: entry)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDelete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    if index < entries.count - 1 {
                        Divider()
                            .padding(.leading, DS.paddingCard)
                            .padding(.trailing, DS.paddingCard)
                    }
                }
            }

            // Add food row
            Button(action: onAdd) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text("Add Food")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.ffSage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .padding(.horizontal, DS.paddingCard)
        }
        .ffCardNoPad()
    }
}

// MARK: - FoodLogRowView

struct FoodLogRowView: View {
    let entry: FoodLogEntryResponse

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.foodItem?.name ?? "Unknown Food")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                    .lineLimit(1)
                Text(servingText)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.ffText2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.caloriesConsumed))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                Text("kcal")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color.ffText3)
            }
        }
        .padding(.horizontal, DS.paddingCard)
        .padding(.vertical, 11)
    }

    private var servingText: String {
        let qty = entry.quantity
        if let serving = entry.foodItem?.servingSizeDescription {
            if qty == 1.0 { return serving }
            return String(format: "%.2g × %@", qty, serving)
        }
        return String(format: "%.2g serving", qty)
    }
}

// MARK: - DailyTotalBar

struct DailyTotalBar: View {
    let totals: DailyMacroTotals?

    var body: some View {
        HStack(spacing: 0) {
            TotalCell(label: "Calories", value: totals?.calories ?? 0, unit: "kcal", color: Color.ffSage)
            TotalCell(label: "Protein",  value: totals?.proteinG ?? 0, unit: "g",    color: Color.ffProtein)
            TotalCell(label: "Carbs",    value: totals?.carbsG ?? 0,   unit: "g",    color: Color.ffCarbs)
            TotalCell(label: "Fat",      value: totals?.fatG ?? 0,     unit: "g",    color: Color.ffFat)
        }
        .padding(.vertical, 13)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.07), radius: 14, y: -4)
        )
    }
}

private struct TotalCell: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.ffText3)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(value))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color.ffText3)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        FoodLogView(coordinator: FoodLogCoordinator())
    }
}
