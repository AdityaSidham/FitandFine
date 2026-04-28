import SwiftUI

// MARK: - WelcomeView  (Cover / Landing page)

struct WelcomeView: View {
    var coordinator: AuthCoordinator

    @State private var heroAppeared   = false
    @State private var logoAppeared   = false
    @State private var textAppeared   = false
    @State private var pillsAppeared  = false
    @State private var buttonAppeared = false

    var body: some View {
        ZStack {
            // ── Full-screen background ──────────────────────────────────────
            Color(red: 0.94, green: 0.99, blue: 0.96)
                .ignoresSafeArea()

            FruitPatternBackground(opacity: 0.28)
                .ignoresSafeArea()

            RadialGradient(
                colors: [DS.Color.accent.opacity(0.16), .clear],
                center: .init(x: 0.5, y: 0.35),
                startRadius: 0,
                endRadius: 260
            )
            .ignoresSafeArea()

            // ── All content in one column ──────────────────────────────────
            VStack(spacing: 0) {

                // ── Top hero section ───────────────────────────────────────
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    // Badge
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.Color.accentDark)
                        Text("Your Smart Nutrition Companion")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.Color.accentDark)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.9))
                            .shadow(color: DS.Color.accent.opacity(0.15), radius: 8, y: 2)
                    )
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : -8)

                    Spacer().frame(height: 28)

                    // App icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(DS.accentGradient)
                            .frame(width: 92, height: 92)
                            .shadow(color: DS.Color.accent.opacity(0.50), radius: 24, y: 10)

                        // Layered leaves icon
                        ZStack {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(.white.opacity(0.30))
                                .rotationEffect(.degrees(-30))
                                .offset(x: 6, y: 4)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(.white)
                                .rotationEffect(.degrees(10))
                        }
                    }
                    .scaleEffect(logoAppeared ? 1 : 0.4)
                    .opacity(logoAppeared ? 1 : 0)

                    Spacer().frame(height: 20)

                    // Wordmark
                    VStack(spacing: 6) {
                        HStack(spacing: 0) {
                            Text("Fit")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("and")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(DS.Color.accentDark)
                            Text("Fine")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        Text("AI-powered nutrition & wellness")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(textAppeared ? 1 : 0)
                    .offset(y: textAppeared ? 0 : 12)

                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)

                // ── Gradient fade ──────────────────────────────────────────
                LinearGradient(
                    colors: [.clear, Color(.systemBackground).opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 48)
                .allowsHitTesting(false)

                // ── Bottom card ────────────────────────────────────────────
                VStack(spacing: 20) {

                    // Feature pills
                    VStack(spacing: 10) {
                        FeaturePill(
                            icon: "barcode.viewfinder",
                            color: DS.Color.accent,
                            text: "Scan barcodes & nutrition labels"
                        )
                        FeaturePill(
                            icon: "brain.head.profile",
                            color: DS.Color.coachPurple,
                            text: "AI-powered nutrition coaching"
                        )
                        FeaturePill(
                            icon: "chart.line.uptrend.xyaxis",
                            color: .orange,
                            text: "Adaptive calorie targets"
                        )
                        FeaturePill(
                            icon: "heart.fill",
                            color: .red,
                            text: "Apple Health integration"
                        )
                    }
                    .opacity(pillsAppeared ? 1 : 0)
                    .offset(y: pillsAppeared ? 0 : 16)

                    // CTA
                    VStack(spacing: 12) {
                        Button {
                            Haptics.medium()
                            coordinator.navigate(to: .signIn)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3)
                                Text("Get Started")
                            }
                        }
                        .buttonStyle(.green)

                        Text("Free to use · No credit card required")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .opacity(buttonAppeared ? 1 : 0)
                    .offset(y: buttonAppeared ? 0 : 12)
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 52)
                .background(Color(.systemBackground).opacity(0.92))
            }
        }
        .navigationBarHidden(true)
        .onAppear { triggerEntrance() }
    }

    private func triggerEntrance() {
        withAnimation(DS.Anim.entrance.delay(0.05))  { heroAppeared   = true }
        withAnimation(DS.Anim.entrance.delay(0.15))  { logoAppeared   = true }
        withAnimation(DS.Anim.entrance.delay(0.26))  { textAppeared   = true }
        withAnimation(DS.Anim.entrance.delay(0.36))  { pillsAppeared  = true }
        withAnimation(DS.Anim.entrance.delay(0.48))  { buttonAppeared = true }
    }
}

// MARK: - Feature Pill

private struct FeaturePill: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color(.systemGray6).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }
}

#Preview {
    WelcomeView(coordinator: AuthCoordinator(appCoordinator: AppCoordinator()))
}
