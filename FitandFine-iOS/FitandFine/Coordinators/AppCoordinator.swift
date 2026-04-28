import SwiftUI

// MARK: - Auth State

enum AuthState {
    case unauthenticated
    case onboarding(userId: String)
    case authenticated(userId: String)
}

// MARK: - App Coordinator

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var authState: AuthState = .unauthenticated

    init() {
        loadAuthState()
    }

    // MARK: - Auth State Loading

    private func loadAuthState() {
        guard
            let accessToken = KeychainHelper.shared.read(service: "fitandfine", account: "access_token"),
            !accessToken.isEmpty,
            let userId = KeychainHelper.shared.read(service: "fitandfine", account: "user_id"),
            !userId.isEmpty
        else {
            authState = .unauthenticated
            return
        }
        // Check if onboarding was completed
        let onboardingDone = KeychainHelper.shared.read(service: "fitandfine", account: "onboarding_complete") == "true"
        if onboardingDone {
            authState = .authenticated(userId: userId)
        } else {
            authState = .onboarding(userId: userId)
        }
    }

    // MARK: - Sign In

    func handleSignIn(
        accessToken: String,
        refreshToken: String,
        userId: String,
        isNewUser: Bool
    ) {
        KeychainHelper.shared.save(accessToken, service: "fitandfine", account: "access_token")
        KeychainHelper.shared.save(refreshToken, service: "fitandfine", account: "refresh_token")
        KeychainHelper.shared.save(userId, service: "fitandfine", account: "user_id")

        if isNewUser {
            authState = .onboarding(userId: userId)
        } else {
            KeychainHelper.shared.save("true", service: "fitandfine", account: "onboarding_complete")
            authState = .authenticated(userId: userId)
        }
    }

    // MARK: - Onboarding Complete

    func handleOnboardingComplete(userId: String) {
        KeychainHelper.shared.save("true", service: "fitandfine", account: "onboarding_complete")
        authState = .authenticated(userId: userId)
    }

    // MARK: - Sign Out

    func handleSignOut() {
        KeychainHelper.shared.delete(service: "fitandfine", account: "access_token")
        KeychainHelper.shared.delete(service: "fitandfine", account: "refresh_token")
        KeychainHelper.shared.delete(service: "fitandfine", account: "user_id")
        KeychainHelper.shared.delete(service: "fitandfine", account: "onboarding_complete")
        authState = .unauthenticated
    }
}

// MARK: - App Coordinator View

struct AppCoordinatorView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            switch coordinator.authState {
            case .unauthenticated:
                AuthCoordinatorView(coordinator: AuthCoordinator(appCoordinator: coordinator))
            case .onboarding(let userId):
                OnboardingCoordinatorView(userId: userId, appCoordinator: coordinator)
            case .authenticated:
                MainTabView(appCoordinator: coordinator)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authStateKey(coordinator.authState))
    }

    private func authStateKey(_ state: AuthState) -> String {
        switch state {
        case .unauthenticated: return "unauthenticated"
        case .onboarding: return "onboarding"
        case .authenticated: return "authenticated"
        }
    }
}

// MARK: - Onboarding Coordinator View (stub — extend as needed)

struct OnboardingCoordinatorView: View {
    let userId: String
    let appCoordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "figure.walk.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.green)

                VStack(spacing: 12) {
                    Text("Welcome to FitandFine!")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text("Let's set up your goals so we can personalize your nutrition plan.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: {
                    appCoordinator.handleOnboardingComplete(userId: userId)
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
