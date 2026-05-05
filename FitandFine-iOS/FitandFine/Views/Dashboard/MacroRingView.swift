import SwiftUI

// MARK: - CalorieRingView

struct CalorieRingView: View {
    let consumed: Double
    let target: Double

    private var progress: Double { min(1.0, target > 0 ? consumed / target : 0) }
    private var remaining: Double { max(0, target - consumed) }

    var body: some View {
        HStack(spacing: 24) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.ffMintLight, lineWidth: 14)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.ffSage, Color.ffTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.75), value: progress)

                VStack(spacing: 1) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ffText1)
                    Text("kcal")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.ffText2)
                }
            }
            .frame(width: 130, height: 130)

            // Stat column
            VStack(alignment: .leading, spacing: 14) {
                CalStatRow(label: "Goal",      value: "\(Int(target))",    unit: "kcal", color: Color.ffTeal)
                CalStatRow(label: "Eaten",     value: "\(Int(consumed))",  unit: "kcal", color: Color.ffSage)
                CalStatRow(label: "Remaining", value: "\(Int(remaining))", unit: "kcal", color: Color.ffText2)
            }

            Spacer(minLength: 0)
        }
        .ffCard()
    }
}

private struct CalStatRow: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.ffText3)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color.ffText3)
            }
        }
    }
}

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
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.12), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)

                VStack(spacing: 0) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ffText1)
                    Text(unit)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Color.ffText3)
                }
            }
            .frame(width: 66, height: 66)

            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                Text("\(Int(remaining)) left")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color.ffText3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .ffCardNoPad()
    }
}

// MARK: - Previews

#Preview("CalorieRingView") {
    CalorieRingView(consumed: 1400, target: 2000)
        .padding()
        .background(Color.ffWarmWhite)
}

#Preview("MacroRingView") {
    HStack(spacing: 12) {
        MacroRingView(consumed: 80, target: 150, ringColor: .ffProtein, label: "Protein", unit: "g")
        MacroRingView(consumed: 120, target: 200, ringColor: .ffCarbs,   label: "Carbs",   unit: "g")
        MacroRingView(consumed: 30,  target: 65,  ringColor: .ffFat,     label: "Fat",     unit: "g")
    }
    .padding()
    .background(Color.ffWarmWhite)
}
