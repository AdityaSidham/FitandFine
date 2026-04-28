import SwiftUI

struct WelcomeView: View {
    var coordinator: AuthCoordinator

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.8, blue: 0.44), Color(red: 0.07, green: 0.54, blue: 0.33)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    Text("FitandFine")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your intelligent nutrition coach")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        FeaturePill(icon: "barcode.viewfinder", text: "Scan food labels & barcodes")
                        FeaturePill(icon: "brain.head.profile", text: "AI-powered nutrition coaching")
                        FeaturePill(icon: "chart.line.uptrend.xyaxis", text: "Adaptive calorie targets")
                    }

                    Button(action: {
                        coordinator.navigate(to: .signIn)
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.07, green: 0.54, blue: 0.33))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)

                    Text("Free to use · No credit card required")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.bottom, 48)
            }
        }
        .navigationBarHidden(true)
    }
}

private struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    WelcomeView(coordinator: AuthCoordinator(appCoordinator: AppCoordinator()))
}
