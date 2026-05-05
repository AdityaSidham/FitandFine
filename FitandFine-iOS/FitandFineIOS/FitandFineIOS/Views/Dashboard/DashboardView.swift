import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject private var healthKit: HealthKitManager
    var coordinator: DashboardCoordinator

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:     return "Good evening"
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(greetingText)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if viewModel.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                                .font(.caption.bold())
                            Text("\(viewModel.currentStreak)d")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.10))
                        .clipShape(Capsule())
                    }
                    Button {
                        Haptics.light()
                        coordinator.navigate(to: .scanner)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(DS.Color.accent.opacity(0.10))
                                .frame(width: 34, height: 34)
                            Image(systemName: "barcode.viewfinder")
                                .foregroundStyle(DS.Color.accent)
                                .font(.system(size: 16, weight: .medium))
                        }
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
            LazyVStack(spacing: DS.Space.md) {

                // ── Hero progress card ────────────────────────────────
                progressHeroCard
                    .entranceAnimation(delay: 0.04)

                // ── Activity (HealthKit) ───────────────────────────────
                if HealthKitManager.isAvailable &&
                    (healthKit.todaySteps > 0 || healthKit.todayActiveCalories > 0) {
                    ActivityCard(
                        steps: healthKit.todaySteps,
                        activeCalories: healthKit.todayActiveCalories
                    )
                    .padding(.horizontal, DS.Space.screenH)
                    .entranceAnimation(delay: 0.10)
                }

                // ── Streak card ───────────────────────────────────────
                StreakCard(streak: viewModel.currentStreak, last7Days: viewModel.last7Days)
                    .entranceAnimation(delay: 0.13)

                // ── Sleep card (HealthKit) ────────────────────────────
                if HealthKitManager.isAvailable {
                    SleepCard(sleep: healthKit.lastNightSleep)
                        .entranceAnimation(delay: 0.16)
                }

                // ── Today's log ───────────────────────────────────────
                todayLogSection
                    .entranceAnimation(delay: 0.19)

                // ── AI recommendations ────────────────────────────────
                RecommendationSection()
                    .entranceAnimation(delay: 0.22)

                // ── Log Food CTA ──────────────────────────────────────
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
                .padding(.horizontal, DS.Space.screenH)
                .padding(.bottom, 32)
                .entranceAnimation(delay: 0.25)
            }
            .padding(.top, 12)
        }
        .refreshable {
            await viewModel.loadDashboard()
            await healthKit.refreshAll()
        }
    }

    // MARK: - Progress Hero Card (white card: big ring + macro mini-rings)

    private var progressHeroCard: some View {
        VStack(spacing: 0) {
            // Section label
            HStack {
                Text("TODAY'S PROGRESS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                Spacer()
                remainingPill
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.top, DS.Space.md)
            .padding(.bottom, DS.Space.sm)

            Divider()
                .opacity(0.4)
                .padding(.horizontal, DS.Space.md)

            // Calorie ring (centre stage)
            VStack(spacing: 4) {
                CalorieRingView(
                    consumed: viewModel.caloriesConsumed,
                    target:   viewModel.caloriesTarget
                )
                .padding(.vertical, DS.Space.sm + 4)

                // Goal row beneath ring
                HStack(spacing: DS.Space.lg) {
                    heroStat(icon: "flag.fill", label: "Goal",
                             value: "\(Int(viewModel.caloriesTarget))",
                             unit: "kcal", color: DS.Color.accent)
                    Divider().frame(height: 28)
                    heroStat(icon: "flame.fill", label: "Burned",
                             value: "\(Int(healthKit.todayActiveCalories))",
                             unit: "kcal", color: .orange)
                    Divider().frame(height: 28)
                    heroStat(icon: "bolt.fill", label: "Net",
                             value: "\(Int(max(0, viewModel.caloriesTarget - viewModel.caloriesConsumed + healthKit.todayActiveCalories)))",
                             unit: "kcal", color: DS.Color.protein)
                }
                .padding(.horizontal, DS.Space.lg)
                .padding(.bottom, DS.Space.md)
            }

            Divider()
                .opacity(0.4)
                .padding(.horizontal, DS.Space.md)

            // Macro mini-rings row
            HStack(spacing: 0) {
                MacroRingView(
                    consumed: viewModel.proteinConsumed,
                    target:   viewModel.proteinTarget,
                    ringColor: DS.Color.protein,
                    label: "Protein", unit: "g"
                )
                .frame(maxWidth: .infinity)

                Divider().frame(height: 60)

                MacroRingView(
                    consumed: viewModel.carbsConsumed,
                    target:   viewModel.carbsTarget,
                    ringColor: DS.Color.carbs,
                    label: "Carbs", unit: "g"
                )
                .frame(maxWidth: .infinity)

                Divider().frame(height: 60)

                MacroRingView(
                    consumed: viewModel.fatConsumed,
                    target:   viewModel.fatTarget,
                    ringColor: DS.Color.fat,
                    label: "Fat", unit: "g"
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, DS.Space.md)
        }
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)
        .padding(.horizontal, DS.Space.screenH)
    }

    private var remainingPill: some View {
        let remaining = max(0, viewModel.caloriesTarget - viewModel.caloriesConsumed)
        return HStack(spacing: 4) {
            Image(systemName: remaining > 0 ? "minus.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10))
            Text(remaining > 0 ? "\(Int(remaining)) kcal left" : "Goal reached!")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(remaining > 0 ? DS.Color.accent : .green)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(remaining > 0 ? DS.Color.accent.opacity(0.08) : Color.green.opacity(0.08))
        .clipShape(Capsule())
    }

    private func heroStat(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color.opacity(0.8))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Today's Log

    @ViewBuilder
    private var todayLogSection: some View {
        let entries = viewModel.state.value?.dailyLog.entries ?? []
        let recentEntries = Array(entries.prefix(3))

        VStack(spacing: 10) {
            HStack(alignment: .center) {
                Text("TODAY'S LOG")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                Spacer()
                if !entries.isEmpty {
                    Button {
                        NotificationCenter.default.post(name: .switchToFoodLogTab, object: nil)
                    } label: {
                        HStack(spacing: 3) {
                            Text("See all")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.Color.accent)
                    }
                }
            }
            .padding(.horizontal, DS.Space.screenH)

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
                            Divider()
                                .padding(.leading, 58)
                                .opacity(0.5)
                        }
                    }
                }
                .background(DS.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)
                .padding(.horizontal, DS.Space.screenH)
            }
        }
    }

    private var emptyLogCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(DS.Color.accent.opacity(0.08))
                    .frame(width: 64, height: 64)
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(DS.Color.accent.opacity(0.55))
            }
            VStack(spacing: 4) {
                Text("Nothing logged yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Start by adding your first meal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                Haptics.light()
                coordinator.navigate(to: .foodSearch)
            } label: {
                Text("Add a meal")
                    .font(.subheadline.bold())
                    .foregroundStyle(DS.Color.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(DS.Color.accent.opacity(0.10))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)
        .padding(.horizontal, DS.Space.screenH)
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
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(mealColor.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: mealIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(mealColor)
            }

            // Name + meal type
            VStack(alignment: .leading, spacing: 2) {
                Text(foodName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(entry.mealType.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Calories + macro pills
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(Int(entry.caloriesConsumed)) kcal")
                    .font(.subheadline.bold())
                    .foregroundStyle(mealColor)
                    .monospacedDigit()
                HStack(spacing: 4) {
                    macroTag("P \(Int(entry.proteinConsumedG))", color: DS.Color.protein)
                    macroTag("C \(Int(entry.carbsConsumedG))",   color: DS.Color.carbs)
                    macroTag("F \(Int(entry.fatConsumedG))",     color: DS.Color.fat)
                }
            }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, 13)
    }

    private func macroTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private var mealColor: Color {
        switch entry.mealType.lowercased() {
        case "breakfast": return Color(red: 0.95, green: 0.60, blue: 0.25) // warm amber
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
