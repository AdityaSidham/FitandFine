import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    var coordinator: DashboardCoordinator

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    var body: some View {
        ZStack {
            Color.ffWarmWhite.ignoresSafeArea()

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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    coordinator.navigate(to: .scanner)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.ffMintLight)
                            .frame(width: 36, height: 36)
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.ffSage)
                    }
                }
            }
        }
        .task { await viewModel.loadDashboard() }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private var loadedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                greetingHeader
                    .padding(.horizontal, DS.paddingPage)

                CalorieRingView(
                    consumed: viewModel.caloriesConsumed,
                    target: viewModel.caloriesTarget
                )
                .padding(.horizontal, DS.paddingPage)

                HStack(spacing: 10) {
                    MacroRingView(
                        consumed: viewModel.proteinConsumed,
                        target: viewModel.proteinTarget,
                        ringColor: .ffProtein,
                        label: "Protein",
                        unit: "g"
                    )
                    MacroRingView(
                        consumed: viewModel.carbsConsumed,
                        target: viewModel.carbsTarget,
                        ringColor: .ffCarbs,
                        label: "Carbs",
                        unit: "g"
                    )
                    MacroRingView(
                        consumed: viewModel.fatConsumed,
                        target: viewModel.fatTarget,
                        ringColor: .ffFat,
                        label: "Fat",
                        unit: "g"
                    )
                }
                .padding(.horizontal, DS.paddingPage)

                todayLogSection

                logFoodButton
                    .padding(.horizontal, DS.paddingPage)
                    .padding(.bottom, 32)
            }
            .padding(.top, 12)
        }
        .refreshable { await viewModel.loadDashboard() }
    }

    // MARK: - Greeting Header

    @ViewBuilder
    private var greetingHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                Text(formattedDate)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.ffText2)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                Text("Today")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ffText2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.ffWarmNeutral)
            .clipShape(Capsule())
        }
    }

    // MARK: - Today Log Section

    @ViewBuilder
    private var todayLogSection: some View {
        let entries = viewModel.state.value?.dailyLog.entries ?? []
        let recentEntries = Array(entries.prefix(3))

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Log")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                Spacer()
                if !entries.isEmpty {
                    Text("See All")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ffSage)
                }
            }
            .padding(.horizontal, DS.paddingPage)

            if recentEntries.isEmpty {
                emptyLogPlaceholder
                    .padding(.horizontal, DS.paddingPage)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentEntries.enumerated()), id: \.element.id) { index, entry in
                        DashboardLogRow(entry: entry)
                        if index < recentEntries.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                                .padding(.trailing, DS.paddingCard)
                        }
                    }
                }
                .ffCardNoPad()
                .padding(.horizontal, DS.paddingPage)
            }
        }
    }

    @ViewBuilder
    private var emptyLogPlaceholder: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.ffMintLight)
                    .frame(width: 56, height: 56)
                Image(systemName: "fork.knife")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.ffSage)
            }
            Text("Nothing logged yet")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ffText2)
            Text("Tap Log Food to start tracking")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.ffText3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .ffCard(background: .white)
    }

    // MARK: - Log Food Button

    @ViewBuilder
    private var logFoodButton: some View {
        Button {
            coordinator.navigate(to: .scanner)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 17))
                Text("Log Food")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.ffSage, Color(red: 0.38, green: 0.62, blue: 0.42)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.cornerCard))
            .shadow(color: Color.ffSage.opacity(0.38), radius: 14, y: 6)
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
}

// MARK: - Dashboard Log Row

private struct DashboardLogRow: View {
    let entry: FoodLogEntryResponse

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(mealColor.opacity(0.13))
                    .frame(width: 40, height: 40)
                Image(systemName: mealIcon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(mealColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.foodItem?.name ?? "Unknown Food")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                    .lineLimit(1)
                Text(entry.mealType.capitalized)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.ffText3)
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
        .padding(.vertical, 13)
    }

    private var mealColor: Color {
        switch entry.mealType.lowercased() {
        case "breakfast": return Color(red: 0.96, green: 0.72, blue: 0.30)
        case "lunch":     return Color.ffSage
        case "dinner":    return Color.ffTeal
        default:          return Color.ffProtein
        }
    }

    private var mealIcon: String {
        switch entry.mealType.lowercased() {
        case "breakfast": return "sunrise.fill"
        case "lunch":     return "sun.max.fill"
        case "dinner":    return "moon.stars.fill"
        default:          return "star.fill"
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(coordinator: DashboardCoordinator())
    }
}
