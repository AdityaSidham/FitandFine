import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject private var healthKit: HealthKitManager
    var coordinator: DashboardCoordinator

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning!"
        case 12..<17: return "Good afternoon!"
        default:     return "Good evening!"
        }
    }

    var body: some View {
        ZStack {
            DS.Color.bgScreen.ignoresSafeArea()

            Group {
                switch viewModel.state {
                case .idle:
                    Color.clear
                case .loading:
                    LoadingView(message: "Loading your dashboard…")
                case .error(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.loadDashboard() }
                    }
                case .loaded:
                    loadedContent
                }
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptics.light()
                    coordinator.navigate(to: .scanner)
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundStyle(DS.Color.accent)
                        .fontWeight(.medium)
                }
            }
        }
        .task { await viewModel.loadDashboard() }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private var loadedContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {

                // ── Greeting ──────────────────────────────────────────
                greetingRow
                    .entranceAnimation(delay: 0.0)

                // ── Dark green hero calorie card ──────────────────────
                calorieHeroCard
                    .entranceAnimation(delay: 0.05)

                // ── Macro bars ────────────────────────────────────────
                macroBarsCard
                    .entranceAnimation(delay: 0.10)

                // ── Activity (HealthKit) ───────────────────────────────
                if HealthKitManager.isAvailable &&
                    (healthKit.todaySteps > 0 || healthKit.todayActiveCalories > 0) {
                    ActivityCard(
                        steps: healthKit.todaySteps,
                        activeCalories: healthKit.todayActiveCalories
                    )
                    .padding(.horizontal)
                    .entranceAnimation(delay: 0.13)
                }

                // ── Streak card ───────────────────────────────────────
                StreakCard(streak: viewModel.currentStreak, last7Days: viewModel.last7Days)
                    .entranceAnimation(delay: 0.15)

                // ── Sleep card (HealthKit) ────────────────────────────
                if HealthKitManager.isAvailable {
                    SleepCard(sleep: healthKit.lastNightSleep)
                        .entranceAnimation(delay: 0.17)
                }

                // ── Today's log ───────────────────────────────────────
                todayLogSection
                    .entranceAnimation(delay: 0.19)

                // ── AI recommendations ────────────────────────────────
                RecommendationSection()
                    .entranceAnimation(delay: 0.23)

                // ── Log Food CTA ──────────────────────────────────────
                logFoodButton
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                    .entranceAnimation(delay: 0.25)
            }
            .padding(.top, 8)
        }
        .refreshable {
            await viewModel.loadDashboard()
            await healthKit.refreshAll()
        }
    }

    // MARK: - Greeting Row

    private var greetingRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingText)
                    .font(.title2.bold())
                    .tracking(-0.3)
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.currentStreak > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.caption.bold())
                    Text("\(viewModel.currentStreak)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                    Text("days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Hero Calorie Card  (dark green, like the prototype)

    @State private var ringAppeared = false

    private var calorieHeroCard: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous)
                .fill(DS.heroGradient)

            // Decorative circles
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 180, height: 180)
                .offset(x: 80, y: -50)
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 140, height: 140)
                .offset(x: -60, y: 70)

            HStack(spacing: 20) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: viewModel.caloriesTarget > 0
                              ? min(1, viewModel.caloriesConsumed / viewModel.caloriesTarget) : 0)
                        .stroke(.white.opacity(0.9),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(DS.Anim.ring, value: viewModel.caloriesConsumed)

                    VStack(spacing: 2) {
                        Text("\(Int(viewModel.caloriesConsumed))")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("kcal")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .frame(width: 120, height: 120)

                // Stats
                VStack(alignment: .leading, spacing: 12) {
                    heroStat(icon: "flag.fill",        label: "Goal",
                             value: "\(Int(viewModel.caloriesTarget)) kcal")
                    heroStat(icon: "minus.circle.fill", label: "Remaining",
                             value: "\(Int(max(0, viewModel.caloriesTarget - viewModel.caloriesConsumed))) kcal")
                    if healthKit.todayActiveCalories > 0 {
                        heroStat(icon: "flame.fill",   label: "Burned",
                                 value: "\(Int(healthKit.todayActiveCalories)) kcal")
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .frame(height: 170)
        .padding(.horizontal)
        .shadow(color: DS.Color.accentDark.opacity(0.4), radius: 24, y: 10)
    }

    private func heroStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.65))
                .font(.caption)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Macro Bars Card

    private var macroBarsCard: some View {
        VStack(spacing: 14) {
            Text("MACROS TODAY")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)

            macroBar(icon: "bolt.fill",       label: "Protein",
                     consumed: viewModel.proteinConsumed, target: viewModel.proteinTarget,
                     color: DS.Color.protein)
            macroBar(icon: "flame.fill",      label: "Carbs",
                     consumed: viewModel.carbsConsumed,   target: viewModel.carbsTarget,
                     color: DS.Color.carbs)
            macroBar(icon: "drop.fill",       label: "Fat",
                     consumed: viewModel.fatConsumed,     target: viewModel.fatTarget,
                     color: DS.Color.fat)
        }
        .appCard(16)
        .padding(.horizontal)
    }

    private func macroBar(icon: String, label: String, consumed: Double,
                          target: Double, color: Color) -> some View {
        let progress = target > 0 ? min(1.0, consumed / target) : 0
        let remaining = max(0, target - consumed)
        return VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                }
                Spacer()
                Text("\(Int(consumed))g")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text("/ \(Int(target))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12)).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [color, color.opacity(0.7)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(DS.Anim.ring, value: progress)
                }
            }
            .frame(height: 8)
            HStack {
                Spacer()
                Text("\(Int(remaining))g left")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Today's Log

    @ViewBuilder
    private var todayLogSection: some View {
        let entries = viewModel.state.value?.dailyLog.entries ?? []
        let recentEntries = Array(entries.prefix(3))

        VStack(spacing: 12) {
            AppSectionHeader(title: "Today's Log") {
                if !entries.isEmpty {
                    Button("See all →") {
                        NotificationCenter.default.post(name: .switchToFoodLogTab, object: nil)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Color.accent)
                }
            }
            .padding(.horizontal)

            if recentEntries.isEmpty {
                emptyLogCard
            } else {
                VStack(spacing: 0) {
                    ForEach(recentEntries) { entry in
                        DashboardLogRow(
                            entry: entry,
                            foodName: viewModel.foodNames[entry.foodItemId] ?? "Loading…"
                        )
                        if entry.id != recentEntries.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .appCard(0)
                .padding(.horizontal)
            }
        }
    }

    private var emptyLogCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 40))
                .foregroundStyle(DS.Color.accent.opacity(0.6))
            Text("Nothing logged yet today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Log your first meal") {
                Haptics.light()
                coordinator.navigate(to: .foodSearch)
            }
            .font(.subheadline.bold())
            .foregroundStyle(DS.Color.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .appCard(0)
        .padding(.horizontal)
    }

    // MARK: - Log Food Button

    private var logFoodButton: some View {
        Button {
            Haptics.medium()
            coordinator.navigate(to: .foodSearch)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.title3)
                Text("Log Food").font(.headline)
            }
        }
        .buttonStyle(.green)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
}

// MARK: - Dashboard Log Row

private struct DashboardLogRow: View {
    let entry: FoodLogEntryResponse
    let foodName: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(mealColor.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: mealIcon)
                    .font(.subheadline)
                    .foregroundStyle(mealColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(foodName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(entry.mealType.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.caloriesConsumed)) kcal")
                    .font(.subheadline.bold())
                    .foregroundStyle(mealColor)
                HStack(spacing: 4) {
                    macroTag("P\(Int(entry.proteinConsumedG))", color: DS.Color.protein)
                    macroTag("C\(Int(entry.carbsConsumedG))",   color: DS.Color.carbs)
                    macroTag("F\(Int(entry.fatConsumedG))",     color: DS.Color.fat)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func macroTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    private var mealColor: Color {
        switch entry.mealType.lowercased() {
        case "breakfast": return .orange
        case "lunch":     return DS.Color.accent
        case "dinner":    return DS.Color.coachPurple
        default:          return DS.Color.protein
        }
    }

    private var mealIcon: String {
        switch entry.mealType.lowercased() {
        case "breakfast": return "sunrise.fill"
        case "lunch":     return "sun.max.fill"
        case "dinner":    return "moon.stars.fill"
        default:          return "leaf.fill"
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(coordinator: DashboardCoordinator())
            .environmentObject(HealthKitManager.shared)
    }
}
