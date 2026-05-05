import SwiftUI

// MARK: - MacroRingView (compact, used in macro-row on Dashboard & FoodDetail)

struct MacroRingView: View {
    let consumed: Double
    let target:   Double
    let ringColor: Color
    let label:    String
    let unit:     String

    @State private var appeared = false

    private var progress:  Double { appeared ? min(1.0, target > 0 ? consumed / target : 0) : 0 }
    private var remaining: Double { max(0, target - consumed) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track
                Circle()
                    .stroke(ringColor.opacity(0.12), lineWidth: 9)
                // Fill
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [ringColor.opacity(0.7), ringColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Anim.ring, value: progress)

                VStack(spacing: 1) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)
            .onAppear {
                withAnimation(DS.Anim.ring.delay(0.15)) { appeared = true }
            }

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ringColor)

            Text("\(Int(remaining))g left")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - CalorieRingView (large hero ring — white card version)

struct CalorieRingView: View {
    let consumed: Double
    let target:   Double
    /// When true the ring is shown on a white card background (Dashboard hero card).
    /// When false it renders standalone (light text on dark surface).
    var cardStyle: Bool = true

    @State private var appeared = false

    private var progress:  Double { appeared ? min(1.0, target > 0 ? consumed / target : 0) : 0 }
    private var remaining: Double { max(0, target - consumed) }
    private var isOver:    Bool   { consumed > target && target > 0 }

    var body: some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(DS.Color.accent.opacity(0.10), lineWidth: 20)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [DS.Color.accentMid, DS.Color.accent, DS.Color.accentDark],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle:   .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DS.Anim.ring, value: progress)
                .shadow(color: DS.Color.accent.opacity(0.25), radius: 6, y: 3)

            // Over-goal indicator arc
            if isOver {
                Circle()
                    .trim(from: 1.0, to: min(1.0, progress))
                    .stroke(Color.orange.opacity(0.6),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Anim.ring, value: progress)
            }

            // Centre text
            VStack(spacing: 3) {
                Text("\(Int(consumed))")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Color.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("kcal")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("of \(Int(target))")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 160, height: 160)
        .onAppear {
            withAnimation(DS.Anim.ring.delay(0.1)) { appeared = true }
        }
    }
}

// MARK: - Previews

#Preview("Macro Rings") {
    HStack(spacing: 24) {
        MacroRingView(consumed: 80,  target: 150, ringColor: DS.Color.protein, label: "Protein", unit: "g")
        MacroRingView(consumed: 120, target: 200, ringColor: DS.Color.carbs,   label: "Carbs",   unit: "g")
        MacroRingView(consumed: 30,  target: 65,  ringColor: DS.Color.fat,     label: "Fat",     unit: "g")
    }
    .padding()
    .background(DS.Color.bgScreen)
}

#Preview("Calorie Ring") {
    VStack {
        CalorieRingView(consumed: 1420, target: 2000)
    }
    .padding(40)
    .background(DS.Color.surface)
}
