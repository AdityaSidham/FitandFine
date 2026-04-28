import SwiftUI

// MARK: - FoodLogView

struct FoodLogView: View {
    @StateObject private var viewModel = FoodLogViewModel()
    var coordinator: FoodLogCoordinator

    private let allMealTypes = ["breakfast", "lunch", "dinner", "snack"]

    var body: some View {
        VStack(spacing: 0) {
            // Date picker
            DatePicker(
                "Date",
                selection: $viewModel.selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            Divider()

            if viewModel.isLoading {
                LoadingView(message: "Loading log...")
            } else {
                List {
                    ForEach(allMealTypes, id: \.self) { meal in
                        let entries = viewModel.entriesByMeal[meal] ?? []
                        Section(header: Text(meal.capitalized)) {
                            ForEach(entries) { entry in
                                FoodLogRowView(entry: entry)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await viewModel.deleteEntry(logId: entry.id) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }

                            Button {
                                coordinator.navigate(to: .addFood)
                            } label: {
                                Label("Add Food", systemImage: "plus")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }

            // Daily total bar pinned at bottom
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
}

// MARK: - FoodLogRowView

struct FoodLogRowView: View {
    let entry: FoodLogEntryResponse

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.foodItem?.name ?? "Unknown Food")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(servingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(entry.caloriesConsumed))")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            + Text(" kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var servingText: String {
        let qty = entry.quantity
        if let serving = entry.foodItem?.servingSizeDescription {
            if qty == 1.0 {
                return serving
            }
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
            TotalCell(label: "Calories", value: totals?.calories ?? 0, unit: "kcal", color: .green)
            Divider().frame(height: 36)
            TotalCell(label: "Protein", value: totals?.proteinG ?? 0, unit: "g", color: .blue)
            Divider().frame(height: 36)
            TotalCell(label: "Carbs", value: totals?.carbsG ?? 0, unit: "g", color: .orange)
            Divider().frame(height: 36)
            TotalCell(label: "Fat", value: totals?.fatG ?? 0, unit: "g", color: .red)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
    }
}

private struct TotalCell: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(value))")
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

#Preview {
    NavigationStack {
        FoodLogView(coordinator: FoodLogCoordinator())
    }
}
