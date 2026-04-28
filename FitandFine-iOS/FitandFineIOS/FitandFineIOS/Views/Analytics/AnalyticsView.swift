import SwiftUI
import Charts
import Combine

// MARK: - Analytics Coordinator View

struct AnalyticsCoordinatorView: View {
    var body: some View {
        NavigationStack {
            AnalyticsView()
        }
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    @StateObject private var vm = AnalyticsViewModel()
    @EnvironmentObject private var healthKit: HealthKitManager

    var body: some View {
        ZStack {
            DS.Color.bgScreen.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.analytics == nil && vm.weightHistory == nil {
                    LoadingView(message: "Loading analytics…")
                } else {
                    content
                }
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: - Main content

    private var content: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                // ── Hero stat tiles ───────────────────────────────────
                heroStatBanner
                    .entranceAnimation(delay: 0.0)

                // ── Health activity ───────────────────────────────────
                if HealthKitManager.isAvailable && (healthKit.todaySteps > 0 || healthKit.todayActiveCalories > 0) {
                    ActivityCard(steps: healthKit.todaySteps, activeCalories: healthKit.todayActiveCalories)
                        .entranceAnimation(delay: 0.03)
                } else if HealthKitManager.isAvailable && !healthKit.hasRequestedAuthorization {
                    HealthKitPermissionBanner()
                        .entranceAnimation(delay: 0.03)
                }

                // ── 30-Day averages ───────────────────────────────────
                averagesCard
                    .entranceAnimation(delay: 0.07)

                // ── Calorie trend ─────────────────────────────────────
                calorieChartCard
                    .entranceAnimation(delay: 0.10)

                // ── Macro split ───────────────────────────────────────
                macroBreakdownCard
                    .entranceAnimation(delay: 0.13)

                // ── Weight trend ──────────────────────────────────────
                weightChartCard
                    .entranceAnimation(delay: 0.16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Hero Stat Banner

    private var heroStatBanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous)
                .fill(DS.heroGradient)

            // Decorative circles
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 140, height: 140)
                .offset(x: 100, y: -40)
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 100, height: 100)
                .offset(x: -60, y: 50)

            VStack(spacing: 12) {
                Text("YOUR PROGRESS")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.70))
                    .tracking(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 0) {
                    heroBannerStat(
                        icon: "flame.fill",
                        label: "Avg / Day",
                        value: vm.analytics.map { "\(Int($0.avgCalories))" } ?? "—",
                        unit: "kcal"
                    )
                    Divider()
                        .frame(height: 44)
                        .overlay(Color.white.opacity(0.2))
                    heroBannerStat(
                        icon: "bolt.fill",
                        label: "Avg Protein",
                        value: vm.analytics.map { "\(Int($0.avgProteinG))" } ?? "—",
                        unit: "g/day"
                    )
                    Divider()
                        .frame(height: 44)
                        .overlay(Color.white.opacity(0.2))
                    heroBannerStat(
                        icon: "calendar.badge.checkmark",
                        label: "Days Logged",
                        value: vm.analytics.map { "\($0.loggedDays)" } ?? "—",
                        unit: "/ \(vm.analytics?.totalDays ?? 30)"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .shadow(color: DS.Color.accentDark.opacity(0.35), radius: 20, y: 8)
    }

    private func heroBannerStat(icon: String, label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.70))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            VStack(spacing: 1) {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 30-Day Averages

    private var averagesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppSectionHeader(title: "30-Day Averages") {
                if let a = vm.analytics {
                    PillLabel(
                        text: "\(a.loggedDays)/\(a.totalDays) days",
                        color: a.loggedDays > a.totalDays / 2 ? DS.Color.accent : .orange,
                        size: .caption
                    )
                }
            }

            if let a = vm.analytics {
                HStack(spacing: 0) {
                    avgCell("Calories", Int(a.avgCalories), "kcal", DS.Color.accent)
                    Divider().frame(height: 44)
                    avgCell("Protein",  Int(a.avgProteinG), "g",    DS.Color.protein)
                    Divider().frame(height: 44)
                    avgCell("Carbs",    Int(a.avgCarbsG),   "g",    DS.Color.carbs)
                    Divider().frame(height: 44)
                    avgCell("Fat",      Int(a.avgFatG),     "g",    DS.Color.fat)
                }
                .background(Color(.systemGray5).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            } else {
                shimmerRow(height: 68)
            }
        }
        .appCard(16)
    }

    private func avgCell(_ label: String, _ value: Int, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Calorie Trend Chart

    private var calorieChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppSectionHeader(title: "Calorie Trend") {
                if let goal = vm.calorieTarget {
                    PillLabel(text: "Goal \(goal) kcal", color: DS.Color.accent, size: .caption)
                }
            }

            if let dailyTotals = vm.analytics?.dailyTotals, !dailyTotals.isEmpty {
                Chart {
                    ForEach(dailyTotals) { day in
                        BarMark(
                            x: .value("Date", shortDate(day.date)),
                            y: .value("Calories", day.calories)
                        )
                        .foregroundStyle(
                            day.calories == 0
                                ? AnyShapeStyle(Color.clear)
                                : AnyShapeStyle(LinearGradient(
                                    colors: [DS.Color.accent, DS.Color.accentMid],
                                    startPoint: .bottom, endPoint: .top
                                ))
                        )
                        .cornerRadius(4)
                    }
                    if let goal = vm.calorieTarget {
                        RuleMark(y: .value("Goal", goal))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundStyle(DS.Color.accent.opacity(0.6))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(DS.Color.accent)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 7)) { _ in AxisValueLabel() }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel()
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    }
                }
                .frame(height: 180)
            } else {
                emptyChartView(icon: "chart.bar", message: "Log meals to see trend", height: 180)
            }
        }
        .appCard(16)
    }

    // MARK: - Macro Breakdown

    private var macroBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppSectionHeader(title: "Macro Split") {
                PillLabel(text: "Last 14 days", color: .secondary, size: .caption)
            }

            if let dailyTotals = vm.analytics?.dailyTotals {
                let recent = Array(dailyTotals.filter { $0.entriesCount > 0 }.suffix(14))
                if recent.isEmpty {
                    emptyChartView(icon: "chart.bar.xaxis", message: "No macro data yet", height: 140)
                } else {
                    Chart {
                        ForEach(recent) { day in
                            BarMark(x: .value("Date", shortDate(day.date)), y: .value("Protein", day.proteinG))
                                .foregroundStyle(by: .value("Macro", "Protein"))
                                .cornerRadius(2)
                            BarMark(x: .value("Date", shortDate(day.date)), y: .value("Carbs", day.carbsG))
                                .foregroundStyle(by: .value("Macro", "Carbs"))
                                .cornerRadius(2)
                            BarMark(x: .value("Date", shortDate(day.date)), y: .value("Fat", day.fatG))
                                .foregroundStyle(by: .value("Macro", "Fat"))
                                .cornerRadius(2)
                        }
                    }
                    .chartForegroundStyleScale([
                        "Protein": DS.Color.protein,
                        "Carbs":   DS.Color.carbs,
                        "Fat":     DS.Color.fat,
                    ])
                    .chartLegend(position: .bottom, alignment: .center)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 4)) { _ in AxisValueLabel() }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                            AxisValueLabel()
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        }
                    }
                    .frame(height: 160)
                }
            } else {
                shimmerRow(height: 160)
            }
        }
        .appCard(16)
    }

    // MARK: - Weight Trend Chart

    private var weightChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppSectionHeader(title: "Weight Trend") {
                if let hist = vm.weightHistory, let rate = hist.weeklyRateKg {
                    let rateColor: Color = rate < -0.05 ? .orange : (rate > 0.05 ? DS.Color.accent : .secondary)
                    PillLabel(
                        text: String(format: "%+.2f kg/wk", rate),
                        color: rateColor,
                        size: .caption
                    )
                }
            }

            if let entries = vm.weightHistory?.entries, !entries.isEmpty {
                Chart {
                    ForEach(entries) { entry in
                        LineMark(
                            x: .value("Date", shortDate(entry.logDate)),
                            y: .value("Weight", entry.weightKg)
                        )
                        .foregroundStyle(DS.Color.accent)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Date", shortDate(entry.logDate)),
                            y: .value("Weight", entry.weightKg)
                        )
                        .foregroundStyle(DS.Color.accent)
                        .symbolSize(28)
                    }

                    ForEach(vm.movingAverage) { pt in
                        LineMark(
                            x: .value("Date", shortDate(pt.date)),
                            y: .value("7-day avg", pt.value)
                        )
                        .foregroundStyle(DS.Color.accent.opacity(0.30))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .interpolationMethod(.monotone)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 14)) { _ in AxisValueLabel() }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel()
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    }
                }
                .frame(height: 200)

                // Legend
                HStack(spacing: 16) {
                    legendDot(DS.Color.accent, "Weight")
                    legendDash(DS.Color.accent.opacity(0.4), "7-day avg")
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            } else {
                emptyChartView(icon: "scalemass.fill", message: "Log your weight to see trend", height: 200)
            }
        }
        .appCard(16)
    }

    // MARK: - Helpers

    private func shortDate(_ str: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return str }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return out.string(from: d)
    }

    private func emptyChartView(icon: String, message: String, height: CGFloat) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(Color(.systemGray4))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
    }

    private func shimmerRow(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
            .fill(Color(.systemGray5))
            .frame(height: height)
            .shimmer()
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
    }

    private func legendDash(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 2)
            Text(label)
        }
    }
}

// MARK: - Moving Average Point

struct MovingAvgPoint: Identifiable {
    let id = UUID()
    let date: String
    let value: Double
}

// MARK: - Analytics ViewModel

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var analytics: LogAnalyticsResponse? = nil
    @Published var weightHistory: WeightHistoryResponse? = nil
    @Published var calorieTarget: Int? = nil
    @Published var isLoading = false
    @Published var movingAverage: [MovingAvgPoint] = []

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let analyticsResult: LogAnalyticsResponse = NetworkClient.shared.get("/logs/analytics?days=30")
        async let weightResult: WeightHistoryResponse   = NetworkClient.shared.get("/weight/history?days=90")
        async let goalResult: GoalResponse              = NetworkClient.shared.get("/goals/")

        analytics     = try? await analyticsResult
        weightHistory = try? await weightResult
        calorieTarget = (try? await goalResult)?.calorieTarget

        computeMovingAverage()
    }

    private func computeMovingAverage() {
        guard let entries = weightHistory?.entries, entries.count >= 3 else {
            movingAverage = []
            return
        }
        let window = 7
        movingAverage = entries.indices.map { i in
            let start = max(0, i - window + 1)
            let slice = entries[start...i]
            let avg   = slice.map { $0.weightKg }.reduce(0, +) / Double(slice.count)
            return MovingAvgPoint(date: entries[i].logDate, value: avg)
        }
    }
}
