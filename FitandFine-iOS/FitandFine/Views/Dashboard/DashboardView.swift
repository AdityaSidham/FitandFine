import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    var coordinator: DashboardCoordinator

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                Color.clear
            case .loading:
                LoadingView(message: "Loading your dashboard...")
            case .error(let message):
                ErrorView(message: message) {
                    Task { await viewModel.loadDashboard() }
                }
            case .loaded:
                loadedContent
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    coordinator.navigate(to: .scanner)
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundStyle(.green)
                }
            }
        }
        .task { await viewModel.loadDashboard() }
    }

    @ViewBuilder
    private var loadedContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Greeting
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greetingText)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // Calorie ring
                CalorieRingView(
                    consumed: viewModel.caloriesConsumed,
                    target: viewModel.caloriesTarget
                )
                .padding(.vertical, 8)

                // Macro rings
                HStack(spacing: 16) {
                    MacroRingView(
                        consumed: viewModel.proteinConsumed,
                        target: viewModel.proteinTarget,
                        ringColor: .blue,
                        label: "Protein",
                        unit: "g"
                    )
                    MacroRingView(
                        consumed: viewModel.carbsConsumed,
                        target: viewModel.carbsTarget,
                        ringColor: .orange,
                        label: "Carbs",
                        unit: "g"
                    )
                    MacroRingView(
                        consumed: viewModel.fatConsumed,
                        target: viewModel.fatTarget,
                        ringColor: .red,
                        label: "Fat",
                        unit: "g"
                    )
                }
                .padding(.horizontal)

                // Today's log section
                todayLogSection

                // Log Food button
                Button {
                    coordinator.navigate(to: .scanner)
                } label: {
                    Label("Log Food", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top, 12)
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }

    @ViewBuilder
    private var todayLogSection: some View {
        let entries = viewModel.state.value?.dailyLog.entries ?? []
        let recentEntries = Array(entries.prefix(3))

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Log")
                    .font(.headline)
                Spacer()
                if !entries.isEmpty {
                    Button("See All") {
                        // Navigate to food log tab — no direct tab switch here
                    }
                    .font(.subheadline)
                    .foregroundStyle(.green)
                }
            }
            .padding(.horizontal)

            if recentEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No food logged yet today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentEntries) { entry in
                        DashboardLogRow(entry: entry)
                        if entry.id != recentEntries.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                .padding(.horizontal)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Dashboard Log Row

private struct DashboardLogRow: View {
    let entry: FoodLogEntryResponse

    var body: some View {
        HStack(spacing: 12) {
            // Meal icon
            Image(systemName: mealIcon(for: entry.mealType))
                .font(.body)
                .foregroundStyle(.green)
                .frame(width: 32, height: 32)
                .background(Color.green.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodItem?.name ?? "Unknown Food")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(entry.mealType.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(entry.caloriesConsumed)) kcal")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func mealIcon(for mealType: String) -> String {
        switch mealType.lowercased() {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        default: return "apple.logo"
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(coordinator: DashboardCoordinator())
    }
}
