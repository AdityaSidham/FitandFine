import SwiftUI

// MARK: - SleepCard

struct SleepCard: View {
    let sleep: SleepStages

    @State private var appeared = false

    private var scoreColor: Color {
        switch sleep.score {
        case 85...: return DS.Color.accent
        case 70..<85: return .blue
        case 55..<70: return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            AppSectionHeader(title: "Last Night's Sleep") {
                if sleep.totalHours > 0 {
                    PillLabel(
                        text: sleep.label,
                        color: scoreColor,
                        size: .caption
                    )
                }
            }

            if sleep.totalHours == 0 {
                emptyState
            } else {
                HStack(spacing: 20) {
                    // Score ring
                    scoreRing
                    // Stage bars
                    stageBars
                }
            }
        }
        .appCard(16)
        .padding(.horizontal)
        .onAppear {
            withAnimation(DS.Anim.ring.delay(0.15)) { appeared = true }
        }
    }

    // MARK: - Score Ring

    private var scoreRing: some View {
        let progress = appeared ? Double(sleep.score) / 100.0 : 0.0
        return ZStack {
            Circle()
                .stroke(scoreColor.opacity(0.12), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    scoreColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DS.Anim.ring, value: appeared)

            VStack(spacing: 2) {
                Text("\(sleep.score)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
                Text("score")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 90, height: 90)
    }

    // MARK: - Stage Bars

    private var stageBars: some View {
        VStack(alignment: .leading, spacing: 9) {
            sleepBar("Deep",  hours: sleep.deepHours,  color: .indigo)
            sleepBar("REM",   hours: sleep.remHours,   color: .purple)
            sleepBar("Core",  hours: sleep.coreHours,  color: .blue.opacity(0.8))
            sleepBar("Awake", hours: sleep.awakeHours, color: Color(.systemGray3))
        }
        .frame(maxWidth: .infinity)
    }

    private func sleepBar(_ label: String, hours: Double, color: Color) -> some View {
        let totalWidth: CGFloat = 1.0
        let ratio = sleep.totalHours > 0 ? min(1, hours / sleep.totalHours) : 0
        let progress = appeared ? ratio : 0.0

        return HStack(spacing: 8) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(DS.Anim.ring, value: appeared)
                }
            }
            .frame(height: 6)

            Text(formatHours(hours))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
                .monospacedDigit()
        }
    }

    private func formatHours(_ h: Double) -> String {
        let total = Int((h * 60).rounded())
        let hrs = total / 60
        let mins = total % 60
        if hrs == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hrs)h" }
        return "\(hrs)h\(mins)m"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.zzz.fill")
                .font(.title2)
                .foregroundStyle(Color(.tertiaryLabel))
            VStack(alignment: .leading, spacing: 3) {
                Text("No sleep data")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Sleep data updates after your next sleep")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    let full = SleepStages(totalHours: 7.5, deepHours: 1.2, remHours: 1.8,
                           coreHours: 4.5, awakeHours: 0.3)
    let poor = SleepStages(totalHours: 4.5, deepHours: 0.5, remHours: 0.6,
                           coreHours: 3.4, awakeHours: 0.8)

    return VStack(spacing: 12) {
        SleepCard(sleep: full)
        SleepCard(sleep: poor)
        SleepCard(sleep: .empty)
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
