import SwiftUI

// MARK: - WeeklyReportView

struct WeeklyReportView: View {
    @ObservedObject var viewModel: CoachViewModel
    @State private var appeared = false

    var body: some View {
        Group {
            if viewModel.isLoadingReport {
                loadingState
            } else if let report = viewModel.weeklyReport {
                reportContent(report)
            } else {
                emptyState
            }
        }
        .navigationTitle("Weekly Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptics.light()
                    Task { await viewModel.loadWeeklyReport() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(DS.Color.accent)
                        .rotationEffect(.degrees(viewModel.isLoadingReport ? 360 : 0))
                        .animation(
                            viewModel.isLoadingReport
                                ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                : .default,
                            value: viewModel.isLoadingReport
                        )
                }
                .disabled(viewModel.isLoadingReport)
            }
        }
        .task {
            if viewModel.weeklyReport == nil {
                await viewModel.loadWeeklyReport()
            }
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

    // MARK: - Report content

    private func reportContent(_ report: WeeklyReportResponse) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Period + logged days badge
                periodHeader(report)
                    .entranceAnimation(delay: 0.0)

                // Adherence card
                adherenceCard(score: report.adherenceScore, deficit: report.estimatedDailyDeficit)
                    .entranceAnimation(delay: 0.05)

                // Summary card
                VStack(alignment: .leading, spacing: 10) {
                    Label("AI Summary", systemImage: "doc.text.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(report.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }
                .appCard(16)
                .entranceAnimation(delay: 0.10)

                // Findings
                if !report.findings.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Findings")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        ForEach(report.findings) { finding in
                            FindingCard(finding: finding)
                        }
                    }
                    .entranceAnimation(delay: 0.14)
                }

                Text("Generated \(formattedDate(report.generatedAt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Period header

    private func periodHeader(_ report: WeeklyReportResponse) -> some View {
        HStack(spacing: 12) {
            Label("\(report.periodStart)  →  \(report.periodEnd)", systemImage: "calendar")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: report.dataDays >= 5 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.caption)
                Text("\(report.dataDays)/7 days")
                    .font(.caption.bold())
            }
            .foregroundStyle(report.dataDays >= 5 ? DS.Color.accent : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((report.dataDays >= 5 ? DS.Color.accent : Color.orange).opacity(0.10))
            .clipShape(Capsule())
        }
        .appCard(14)
    }

    // MARK: - Adherence card

    private func adherenceCard(score: Double, deficit: Double?) -> some View {
        HStack(spacing: 20) {
            // Animated ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 9)
                    .frame(width: 88, height: 88)
                Circle()
                    .trim(from: 0, to: appeared ? score : 0)
                    .stroke(
                        adherenceColor(score),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 88, height: 88)
                    .animation(.easeOut(duration: 1.0).delay(0.15), value: appeared)
                VStack(spacing: 2) {
                    Text("\(Int(score * 100))%")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(adherenceColor(score))
                    Text("Adherence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(adherenceLabel(score))
                    .font(.headline)
                Text(adherenceSubtitle(score))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let deficit {
                    HStack(spacing: 5) {
                        Image(systemName: deficit >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .foregroundStyle(deficit >= 0 ? DS.Color.accent : .orange)
                            .font(.caption)
                        Text(deficit >= 0
                             ? "~\(Int(deficit)) kcal/day deficit"
                             : "~\(Int(abs(deficit))) kcal/day surplus")
                            .font(.caption.bold())
                            .foregroundStyle(deficit >= 0 ? DS.Color.accent : .orange)
                    }
                }
            }

            Spacer()
        }
        .appCard(16)
        .onAppear { appeared = true }
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
            Text("Analysing your week with AI…")
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
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 56))
                .foregroundStyle(DS.Color.accent.opacity(0.7))
            Text("Weekly Report")
                .font(.title2.bold())
            Text("Log at least 3 days of meals to get a personalised AI analysis of your nutrition patterns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            PrimaryButton(title: "Generate Report") {
                Task { await viewModel.loadWeeklyReport() }
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func adherenceColor(_ score: Double) -> Color {
        score >= 0.75 ? DS.Color.accent : score >= 0.5 ? .orange : .red
    }

    private func adherenceLabel(_ score: Double) -> String {
        score >= 0.85 ? "Excellent week!" : score >= 0.65 ? "Good progress" : "Room to improve"
    }

    private func adherenceSubtitle(_ score: Double) -> String {
        score >= 0.85 ? "You hit your targets consistently." :
        score >= 0.65 ? "Most days were on track." :
        "Try logging every meal for better insights."
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .short
            return out.string(from: date)
        }
        return iso
    }
}

// MARK: - Finding Card

private struct FindingCard: View {
    let finding: WeeklyFinding
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                Haptics.select()
                withAnimation(DS.Anim.spring) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    // Severity icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(severityColor.opacity(0.14))
                            .frame(width: 34, height: 34)
                        Image(systemName: severityIcon)
                            .foregroundStyle(severityColor)
                            .font(.subheadline)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(finding.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(finding.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(expanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Recommendation (expanded)
            if expanded {
                Divider().padding(.horizontal, 14)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline)
                        .padding(.top, 1)
                    Text(finding.recommendation)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            severityColor.opacity(0.05)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(severityColor.opacity(0.20), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    private var severityColor: Color {
        switch finding.severity {
        case "critical": return .red
        case "warning":  return .orange
        default:         return DS.Color.accent
        }
    }

    private var severityIcon: String {
        switch finding.severity {
        case "critical": return "exclamationmark.octagon.fill"
        case "warning":  return "exclamationmark.triangle.fill"
        default:         return "checkmark.circle.fill"
        }
    }
}
