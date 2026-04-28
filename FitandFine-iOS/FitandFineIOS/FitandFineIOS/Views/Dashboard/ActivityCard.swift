import SwiftUI

// MARK: - Activity Card

struct ActivityCard: View {
    let steps: Int
    let activeCalories: Double

    private let stepGoal: Int = 10_000

    @State private var appeared = false

    private var stepProgress: Double {
        appeared ? min(Double(steps) / Double(stepGoal), 1.0) : 0
    }

    var body: some View {
        HStack(spacing: 16) {
            // Steps ring
            ZStack {
                Circle()
                    .stroke(DS.Color.accent.opacity(0.14), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: stepProgress)
                    .stroke(DS.Color.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Anim.ring, value: stepProgress)

                VStack(spacing: 0) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.Color.accent)
                    Text(steps >= 1000
                         ? String(format: "%.1fk", Double(steps) / 1000)
                         : "\(steps)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 54, height: 54)
            .onAppear {
                withAnimation(DS.Anim.ring.delay(0.2)) { appeared = true }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("\(Int(activeCalories)) kcal burned")
                        .font(.subheadline.bold())
                } icon: {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                }

                Label {
                    Text("\(steps.formatted()) / \(stepGoal.formatted()) steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "shoeprints.fill")
                        .foregroundStyle(DS.Color.accent)
                        .font(.caption)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
                Text("\(Int(stepProgress * 100))%")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .appCard(14)
    }
}

// MARK: - HealthKit Permission Banner

struct HealthKitPermissionBanner: View {
    @EnvironmentObject private var healthKit: HealthKitManager

    var body: some View {
        if HealthKitManager.isAvailable && !healthKit.hasRequestedAuthorization {
            Button {
                Haptics.light()
                Task { await healthKit.requestAuthorization() }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connect Apple Health")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Sync steps, calories & weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .appCard(14)
        }
    }
}
