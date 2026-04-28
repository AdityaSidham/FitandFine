import SwiftUI

// MARK: - MacroRingView

struct MacroRingView: View {
    let consumed: Double
    let target: Double
    let ringColor: Color
    let label: String
    let unit: String

    private var progress: Double { min(1.0, target > 0 ? consumed / target : 0) }
    private var remaining: Double { max(0, target - consumed) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(ringColor.opacity(0.15), lineWidth: 10)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)

                // Center text
                VStack(spacing: 2) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text("\(Int(remaining)) left")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - CalorieRingView

struct CalorieRingView: View {
    let consumed: Double
    let target: Double

    private var progress: Double { min(1.0, target > 0 ? consumed / target : 0) }
    private var remaining: Double { max(0, target - consumed) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.green.opacity(0.15), lineWidth: 16)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.green, Color(red: 0.07, green: 0.54, blue: 0.33)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: progress)

                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("of \(Int(target)) goal")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 160, height: 160)

            Text("\(Int(remaining)) kcal remaining")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("MacroRingView") {
    HStack(spacing: 24) {
        MacroRingView(consumed: 80, target: 150, ringColor: .blue, label: "Protein", unit: "g")
        MacroRingView(consumed: 120, target: 200, ringColor: .orange, label: "Carbs", unit: "g")
        MacroRingView(consumed: 30, target: 65, ringColor: .red, label: "Fat", unit: "g")
    }
    .padding()
}

#Preview("CalorieRingView") {
    CalorieRingView(consumed: 1400, target: 2000)
        .padding()
}
