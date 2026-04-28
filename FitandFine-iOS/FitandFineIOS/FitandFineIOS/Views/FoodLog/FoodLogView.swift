import SwiftUI

// MARK: - FoodLogView

struct FoodLogView: View {
    @StateObject private var viewModel = FoodLogViewModel()
    var coordinator: FoodLogCoordinator

    private let allMealTypes = ["breakfast", "lunch", "dinner", "snack"]

    var body: some View {
        ZStack {
            DS.Color.bgScreen.ignoresSafeArea()
            Group {
                if viewModel.isLoading && viewModel.dailyLog == nil {
                    LoadingView(message: "Loading log…")
                } else {
                    logContent
                }
            }
        }
        .navigationTitle("Food Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptics.light()
                    coordinator.navigate(to: .addFood)
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.accent)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                DatePicker("", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .labelsHidden()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let totals = viewModel.dailyLog?.totals {
                DailyTotalBar(totals: totals)
            }
        }
        .task { await viewModel.loadLog() }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task { await viewModel.loadLog() }
        }
        .refreshable { await viewModel.loadLog() }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Log Content

    @ViewBuilder
    private var logContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(Array(allMealTypes.enumerated()), id: \.element) { idx, meal in
                    let entries = viewModel.entriesByMeal[meal] ?? []
                    MealSection(
                        meal: meal,
                        entries: entries,
                        foodNames: viewModel.foodNames,
                        onDelete: { id in Task { await viewModel.deleteEntry(logId: id) } },
                        onAdd: { Haptics.light(); coordinator.navigate(to: .addFood) }
                    )
                    .entranceAnimation(delay: Double(idx) * 0.06)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 100) // space for total bar
        }
    }
}

// MARK: - Meal Section Card

private struct MealSection: View {
    let meal: String
    let entries: [FoodLogEntryResponse]
    let foodNames: [String: String]
    let onDelete: (String) -> Void
    let onAdd: () -> Void

    @State private var isExpanded = true

    private var totalCal: Double { entries.reduce(0) { $0 + $1.caloriesConsumed } }

    var body: some View {
        VStack(spacing: 0) {
            // Section header — tap to collapse
            Button {
                Haptics.select()
                withAnimation(DS.Anim.spring) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(mealColor.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: mealIcon)
                            .foregroundStyle(mealColor)
                            .font(.subheadline.weight(.semibold))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(meal.capitalized)
                            .font(.headline)
                        if !entries.isEmpty {
                            Text("\(entries.count) item\(entries.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if totalCal > 0 {
                        Text("\(Int(totalCal)) kcal")
                            .font(.subheadline.bold())
                            .foregroundStyle(mealColor)
                            .monospacedDigit()
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(mealColor.opacity(0.05))
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 16)

                VStack(spacing: 0) {
                    if entries.isEmpty {
                        HStack {
                            Text("Nothing logged")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    } else {
                        ForEach(entries) { entry in
                            SwipeToDeleteRow {
                                FoodLogRowView(
                                    entry: entry,
                                    foodName: foodNames[entry.foodItemId],
                                    accentColor: mealColor
                                )
                            } onDelete: {
                                Haptics.warning()
                                onDelete(entry.id)
                            }
                            if entry.id != entries.last?.id {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }

                    Divider().padding(.horizontal, 16)

                    Button(action: onAdd) {
                        Label("Add food", systemImage: "plus")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DS.Color.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)
    }

    private var mealColor: Color {
        switch meal {
        case "breakfast": return .orange
        case "lunch":     return DS.Color.accent
        case "dinner":    return DS.Color.coachPurple
        default:          return DS.Color.protein
        }
    }

    private var mealIcon: String {
        switch meal {
        case "breakfast": return "sunrise.fill"
        case "lunch":     return "sun.max.fill"
        case "dinner":    return "moon.stars.fill"
        default:          return "leaf.fill"
        }
    }
}

// MARK: - FoodLogRowView

struct FoodLogRowView: View {
    let entry: FoodLogEntryResponse
    var foodName: String?
    var accentColor: Color = DS.Color.accent

    var body: some View {
        HStack(spacing: 0) {
            // Left color accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 3, height: 36)
                .padding(.leading, 14)
                .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 3) {
                Text(foodName ?? "Loading…")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .redacted(reason: foodName == nil ? .placeholder : [])

                Text(servingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(entry.caloriesConsumed)) kcal")
                    .font(.subheadline.bold())
                    .foregroundStyle(accentColor)

                HStack(spacing: 5) {
                    macroTag("P\(Int(entry.proteinConsumedG))", color: DS.Color.protein)
                    macroTag("C\(Int(entry.carbsConsumedG))",   color: DS.Color.carbs)
                    macroTag("F\(Int(entry.fatConsumedG))",     color: DS.Color.fat)
                }
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 13)
    }

    private func macroTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private var servingText: String {
        String(format: "×%.2g serving", entry.quantity)
    }
}

// MARK: - Swipe-to-Delete Row
// Custom implementation because .swipeActions only works inside List, not LazyVStack.

struct SwipeToDeleteRow<Content: View>: View {
    @ViewBuilder let content: Content
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var deleteRevealed = false

    private let deleteWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button revealed behind the row
            Button {
                withAnimation(DS.Anim.springFast) {
                    offset = 0
                    deleteRevealed = false
                }
                // Small delay so the row snaps back before the network call
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onDelete() }
            } label: {
                ZStack {
                    Color.red
                    VStack(spacing: 3) {
                        Image(systemName: "trash.fill")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Delete")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: deleteWidth)
                .frame(maxHeight: .infinity)
            }
            .opacity(deleteRevealed ? 1 : 0)

            // Foreground content
            content
                .offset(x: offset)
                .background(DS.Color.surface)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            // Only handle clearly horizontal drags
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let base: CGFloat = deleteRevealed ? -deleteWidth : 0
                            let raw = base + value.translation.width
                            offset = max(-deleteWidth, min(0, raw))
                            if offset < -8 { withAnimation(.none) { deleteRevealed = true } }
                        }
                        .onEnded { value in
                            withAnimation(DS.Anim.springFast) {
                                if offset < -deleteWidth * 0.45 {
                                    offset = -deleteWidth
                                    deleteRevealed = true
                                } else {
                                    offset = 0
                                    deleteRevealed = false
                                }
                            }
                        }
                )
                // Tap outside the delete button to close
                .onTapGesture {
                    if deleteRevealed {
                        withAnimation(DS.Anim.springFast) {
                            offset = 0
                            deleteRevealed = false
                        }
                    }
                }
        }
        .clipped()
    }
}

// MARK: - Daily Total Bar

struct DailyTotalBar: View {
    let totals: DailyMacroTotals?

    var body: some View {
        HStack(spacing: 0) {
            StatCell(label: "Calories", value: "\(Int(totals?.calories ?? 0))", color: DS.Color.accent, subtext: "kcal")
            Divider().frame(height: 34)
            StatCell(label: "Protein",  value: "\(Int(totals?.proteinG ?? 0))", color: DS.Color.protein, subtext: "g")
            Divider().frame(height: 34)
            StatCell(label: "Carbs",    value: "\(Int(totals?.carbsG ?? 0))",   color: DS.Color.carbs, subtext: "g")
            Divider().frame(height: 34)
            StatCell(label: "Fat",      value: "\(Int(totals?.fatG ?? 0))",     color: DS.Color.fat, subtext: "g")
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.5)
        }
    }
}

#Preview {
    NavigationStack {
        FoodLogView(coordinator: FoodLogCoordinator())
    }
}
