import SwiftUI

// MARK: - MacroRingView (compact, used in older layouts & food detail)

struct MacroRingView: View {
    let consumed: Double
    let target: Double
    let ringColor: Color
    let label: String
    let unit: String

    @State private var appeared = false

    private var progress: Double { appeared ? min(1.0, target > 0 ? consumed / target : 0) : 0 }
    private var remaining: Double { max(0, target - consumed) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.14), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Anim.ring, value: progress)

                VStack(spacing: 1) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .onAppear {
                withAnimation(DS.Anim.ring.delay(0.15)) { appeared = true }
            }

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(Int(remaining))g left")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - CalorieRingView (large hero ring)

struct CalorieRingView: View {
    let consumed: Double
    let target: Double

    @State private var appeared = false

    private var progress: Double { appeared ? min(1.0, target > 0 ? consumed / target : 0) : 0 }
    private var remaining: Double { max(0, target - consumed) }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(DS.Color.accent.opacity(0.12), lineWidth: 18)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DS.accentGradient,
                            style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Anim.ring, value: progress)

                VStack(spacing: 4) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("of \(Int(target))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 170, height: 170)
            .onAppear {
                withAnimation(DS.Anim.ring.delay(0.1)) { appeared = true }
            }

            HStack(spacing: 6) {
                Image(systemName: remaining > 0 ? "minus.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(remaining > 0 ? DS.Color.accent : .orange)
                    .font(.caption)
                Text(remaining > 0
                     ? "\(Int(remaining)) kcal remaining"
                     : "\(Int(-remaining)) kcal over goal")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(remaining > 0 ? Color(.secondaryLabel) : Color.orange)
            }
        }
    }
}

// MARK: - Previews

#Preview("Macro Rings") {
    HStack(spacing: 20) {
        MacroRingView(consumed: 80, target: 150, ringColor: .blue,   label: "Protein", unit: "g")
        MacroRingView(consumed: 120, target: 200, ringColor: .orange, label: "Carbs",   unit: "g")
        MacroRingView(consumed: 30,  target: 65,  ringColor: .red,    label: "Fat",     unit: "g")
    }
    .padding()
}

#Preview("Calorie Ring") {
    CalorieRingView(consumed: 1420, target: 2000).padding()
}
