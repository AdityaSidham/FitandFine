import SwiftUI
import Combine

// MARK: - ProgressEvaluationView

struct ProgressEvaluationView: View {
    @StateObject private var vm = ProgressEvaluationViewModel()
    @State private var showAdjustConfirm = false
    @State private var appeared = false

    var body: some View {
        Group {
            if vm.isLoading {
                loadingState
            } else if let eval = vm.evaluation {
                evalContent(eval)
            } else {
                emptyState
            }
        }
        .navigationTitle("Progress Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptics.light()
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(DS.Color.accent)
                        .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                        .animation(
                            vm.isLoading
                                ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                : .default,
                            value: vm.isLoading
                        )
                }
                .disabled(vm.isLoading)
            }
        }
        .task { await vm.load() }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        .sheet(isPresented: $showAdjustConfirm) {
            if let eval = vm.evaluation {
                GoalAdjustmentSheet(
                    proposal: eval.adjustment,
                    goalId: vm.activeGoalId ?? "",
                    onApply: { Task { await vm.applyAdjustment(); showAdjustConfirm = false } },
                    onDismiss: { showAdjustConfirm = false }
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Main content

    private func evalContent(_ eval: ProgressEvaluationResponse) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Status banner
                statusBanner(eval)
                    .entranceAnimation(delay: 0.0)

                // Stats grid
                statsGrid(eval)
                    .entranceAnimation(delay: 0.05)

                // Narrative
                VStack(alignment: .leading, spacing: 10) {
                    Label("AI Assessment", systemImage: "brain.head.profile")
                        .font(.headline)
                    Text(eval.narrative)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }
                .appCard(16)
                .entranceAnimation(delay: 0.10)

                // Adjustment card
                if eval.adjustment.action != "no_change" {
                    adjustmentCard(eval.adjustment) {
                        Haptics.medium()
                        showAdjustConfirm = true
                    }
                    .entranceAnimation(delay: 0.14)
                }

                // Applied success
                if vm.adjustmentApplied {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DS.Color.accent)
                        Text("Calorie target updated to \(eval.adjustment.newCalorieTarget) kcal/day")
                            .font(.subheadline.bold())
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(DS.Color.accent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(DS.Anim.spring, value: vm.adjustmentApplied)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Status banner

    private func statusBanner(_ eval: ProgressEvaluationResponse) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor(eval).opacity(0.14))
                    .frame(width: 60, height: 60)
                Image(systemName: statusIcon(eval))
                    .font(.title2)
                    .foregroundStyle(statusColor(eval))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(statusLabel(eval))
                    .font(.title3.bold())

                HStack(spacing: 6) {
                    PillLabel(text: "\(eval.weeksEvaluated) weeks", color: .secondary, size: .caption)
                    PillLabel(text: "\(eval.weightReadings) weight logs", color: .secondary, size: .caption)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(statusColor(eval).opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(statusColor(eval).opacity(0.20), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    // MARK: - Stats grid

    private func statsGrid(_ eval: ProgressEvaluationResponse) -> some View {
        HStack(spacing: 0) {
            statCell(
                label: "Actual Change",
                value: eval.avgWeeklyChangeKg.map { String(format: "%+.2f kg/wk", $0) } ?? "—",
                color: .primary
            )
            Divider().frame(height: 44)
            statCell(
                label: "Expected",
                value: eval.expectedWeeklyChangeKg.map { String(format: "%+.2f kg/wk", $0) } ?? "—",
                color: .secondary
            )
        }
        .appCard(0)
        .padding(.vertical, 0)
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption2.uppercaseSmallCaps())
                .foregroundStyle(.secondary)
                .tracking(0.4)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Adjustment card

    private func adjustmentCard(_ adj: GoalAdjustmentProposal, onTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.blue)
                        .font(.subheadline)
                }
                Text("Suggested Adjustment")
                    .font(.headline)
                Spacer()
                PillLabel(
                    text: "\(Int(adj.confidence * 100))% confidence",
                    color: .blue,
                    size: .caption2
                )
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(adj.calorieDelta > 0 ? "+" : "")\(adj.calorieDelta) kcal/day")
                    .font(.title3.bold())
                    .foregroundStyle(adj.calorieDelta < 0 ? .orange : DS.Color.accent)
                Text("→ new target: \(adj.newCalorieTarget) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(adj.reasoning)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            Button(action: onTap) {
                Text("Review & Apply")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            }
            .disabled(vm.adjustmentApplied)
        }
        .appCard(16)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Loading state

    private var loadingState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(DS.Color.accent.opacity(0.10))
                    .frame(width: 80, height: 80)
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(DS.Color.accent)
            }
            Text("Evaluating your progress…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "scalemass.fill")
                .font(.system(size: 56))
                .foregroundStyle(DS.Color.accent.opacity(0.7))
            Text("Progress Check")
                .font(.title2.bold())
            Text("Log your weight at least 3 times over 4 weeks to unlock plateau detection and personalised goal adjustments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            PrimaryButton(title: "Check Progress") { Task { await vm.load() } }
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func statusColor(_ e: ProgressEvaluationResponse) -> Color {
        switch e.progressStatus {
        case "on_track":          return DS.Color.accent
        case "plateau":           return .orange
        case "insufficient_data": return .secondary
        default:                  return .red
        }
    }

    private func statusIcon(_ e: ProgressEvaluationResponse) -> String {
        switch e.progressStatus {
        case "on_track":          return "checkmark.circle.fill"
        case "plateau":           return "pause.circle.fill"
        case "insufficient_data": return "questionmark.circle.fill"
        default:                  return "exclamationmark.circle.fill"
        }
    }

    private func statusLabel(_ e: ProgressEvaluationResponse) -> String {
        switch e.progressStatus {
        case "on_track":          return "On Track"
        case "plateau":           return "Plateau Detected"
        case "insufficient_data": return "Not Enough Data"
        default:                  return "Off Track"
        }
    }
}

// MARK: - Goal Adjustment Confirmation Sheet

private struct GoalAdjustmentSheet: View {
    let proposal: GoalAdjustmentProposal
    let goalId: String
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 34))
                        .foregroundStyle(.blue)
                }

                Text("Adjust Calorie Target?")
                    .font(.title2.bold())

                // Summary
                VStack(spacing: 0) {
                    HStack {
                        Text("New daily target")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(proposal.newCalorieTarget) kcal")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                    .padding(14)

                    Divider()

                    HStack {
                        Text("Change")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(proposal.calorieDelta > 0 ? "+" : "")\(proposal.calorieDelta) kcal")
                            .font(.subheadline.bold())
                            .foregroundStyle(proposal.calorieDelta < 0 ? .orange : DS.Color.accent)
                    }
                    .padding(14)
                }
                .background(DS.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)

                Text(proposal.reasoning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text("You can always update your goal again from the Profile tab.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                // Actions
                VStack(spacing: 10) {
                    Button("Apply Adjustment") { onApply() }
                        .buttonStyle(.green)
                    Button("Not Now") { onDismiss() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }
}

// MARK: - ProgressEvaluationViewModel

@MainActor
class ProgressEvaluationViewModel: ObservableObject {
    @Published var evaluation: ProgressEvaluationResponse? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var adjustmentApplied = false
    @Published var activeGoalId: String? = nil

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        adjustmentApplied = false
        do {
            async let evalResult: ProgressEvaluationResponse = NetworkClient.shared.get("/ai/progress-evaluation")
            async let goalResult: GoalResponse? = try? NetworkClient.shared.get("/goals/")
            let (eval, goal) = try await (evalResult, goalResult)
            evaluation = eval
            activeGoalId = goal?.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyAdjustment() async {
        guard let eval = evaluation, let goalId = activeGoalId else { return }
        let req = ApplyAdjustmentRequest(
            newCalorieTarget: eval.adjustment.newCalorieTarget,
            goalId: goalId
        )
        do {
            let _: GoalResponse = try await NetworkClient.shared.post(
                "/ai/progress-evaluation/apply", body: req
            )
            adjustmentApplied = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
