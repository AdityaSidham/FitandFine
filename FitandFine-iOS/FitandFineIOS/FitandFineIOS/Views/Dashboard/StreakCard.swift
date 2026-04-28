import SwiftUI

// MARK: - StreakCard

struct StreakCard: View {
    let streak: Int
    let last7Days: [DailyMacroSummary]   // newest last

    @State private var appeared = false

    private var motivationalText: String {
        switch streak {
        case 0:       return "Start your streak today!"
        case 1:       return "Great start — keep it going!"
        case 2...3:   return "Building momentum!"
        case 4...6:   return "You're on a roll!"
        case 7...13:  return "One week strong!"
        case 14...20: return "Two-week warrior!"
        case 21...29: return "Incredible consistency!"
        default:      return "Unstoppable!"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DS.Color.accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: streak > 0 ? "flame.fill" : "flame")
                        .foregroundStyle(streak > 0 ? DS.Color.accent : Color(.tertiaryLabel))
                        .font(.title3)
                        .symbolEffect(.bounce, value: appeared)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(streak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(streak > 0 ? DS.Color.accent : Color(.secondaryLabel))
                            .contentTransition(.numericText())
                            .animation(DS.Anim.springFast, value: streak)
                        Text(streak == 1 ? "day streak" : "day streak")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(motivationalText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if streak >= 7 {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2.bold())
                        Text("\(streak)d")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(DS.Color.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DS.Color.accent.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            // 7-day chain
            if !last7Days.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(last7Days.enumerated()), id: \.offset) { idx, day in
                        ChainDot(day: day, index: idx, appeared: appeared)
                    }
                }
                .frame(maxWidth: .infinity)

                // Day labels
                HStack(spacing: 6) {
                    ForEach(Array(last7Days.enumerated()), id: \.offset) { idx, day in
                        Text(dayLabel(for: day.date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .appCard(16)
        .padding(.horizontal)
        .onAppear {
            withAnimation(DS.Anim.spring.delay(0.2)) { appeared = true }
        }
    }

    private func dayLabel(for dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "EEE"
        return String(out.string(from: d).prefix(1))
    }
}

// MARK: - Chain Dot

private struct ChainDot: View {
    let day: DailyMacroSummary
    let index: Int
    let appeared: Bool

    private var isLogged: Bool { day.entriesCount > 0 }
    private var isToday: Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return day.date == f.string(from: Date())
    }

    var body: some View {
        ZStack {
            if isLogged {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DS.Color.accentMid, DS.Color.accentDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(appeared ? 1 : 0.2)
                    .animation(DS.Anim.spring.delay(Double(index) * 0.05), value: appeared)

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared ? 1 : 0)
                    .animation(DS.Anim.spring.delay(Double(index) * 0.05 + 0.1), value: appeared)
            } else {
                Circle()
                    .strokeBorder(
                        isToday ? DS.Color.accent.opacity(0.5) : Color(.systemGray4),
                        lineWidth: isToday ? 2 : 1.5
                    )
                    .scaleEffect(appeared ? 1 : 0.2)
                    .animation(DS.Anim.spring.delay(Double(index) * 0.05), value: appeared)

                if isToday {
                    Circle()
                        .fill(DS.Color.accent.opacity(0.12))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Preview

#Preview {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let days: [DailyMacroSummary] = (0..<7).reversed().map { i in
        let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
        return DailyMacroSummary(
            date: formatter.string(from: date),
            calories: i < 2 ? 0 : 1800,
            proteinG: 120, carbsG: 200, fatG: 60,
            entriesCount: i < 2 ? 0 : 3
        )
    }

    return VStack {
        StreakCard(streak: 5, last7Days: days)
        StreakCard(streak: 0, last7Days: days)
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
