import SwiftUI

struct WelcomeView: View {
    var coordinator: AuthCoordinator

    var body: some View {
        ZStack {
            Color.ffWarmWhite.ignoresSafeArea()

            // Soft ambient blobs
            GeometryReader { geo in
                Circle()
                    .fill(Color.ffMint.opacity(0.40))
                    .frame(width: 340, height: 340)
                    .offset(x: geo.size.width * 0.38, y: -80)
                    .blur(radius: 70)

                Circle()
                    .fill(Color.ffTeal.opacity(0.22))
                    .frame(width: 260, height: 260)
                    .offset(x: -50, y: geo.size.height * 0.62)
                    .blur(radius: 60)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo lockup
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.ffSage, Color.ffTeal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 92, height: 92)
                            .shadow(color: Color.ffSage.opacity(0.45), radius: 22, y: 8)

                        Image(systemName: "leaf.fill")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 8) {
                        Text("FitandFine")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ffText1)

                        Text("Your intelligent nutrition coach")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.ffText2)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                // Feature cards
                VStack(spacing: 10) {
                    WelcomeFeatureCard(
                        icon: "barcode.viewfinder",
                        color: Color.ffSage,
                        title: "Scan Food Labels",
                        subtitle: "Instant nutrition from barcodes & photos"
                    )
                    WelcomeFeatureCard(
                        icon: "brain.head.profile",
                        color: Color.ffTeal,
                        title: "AI Nutrition Coach",
                        subtitle: "Personalized insights powered by AI"
                    )
                    WelcomeFeatureCard(
                        icon: "chart.line.uptrend.xyaxis",
                        color: Color.ffProtein,
                        title: "Adaptive Targets",
                        subtitle: "Goals that evolve with your progress"
                    )
                }
                .padding(.horizontal, DS.paddingPage)

                Spacer(minLength: 28)

                // CTA
                VStack(spacing: 12) {
                    Button {
                        coordinator.navigate(to: .signIn)
                    } label: {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                LinearGradient(
                                    colors: [Color.ffSage, Color(red: 0.38, green: 0.62, blue: 0.42)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.cornerCard))
                            .shadow(color: Color.ffSage.opacity(0.42), radius: 18, y: 7)
                    }
                    .padding(.horizontal, DS.paddingPage)

                    Text("Free to use · No credit card required")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.ffText3)
                }
                .padding(.bottom, 52)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Feature Card

private struct WelcomeFeatureCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(color.opacity(0.13))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.ffText2)
            }

            Spacer()
        }
        .ffCard(padding: 13)
    }
}

#Preview {
    WelcomeView(coordinator: AuthCoordinator(appCoordinator: AppCoordinator()))
}
