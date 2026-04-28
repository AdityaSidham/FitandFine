import Foundation
import Combine

// MARK: - Sign-In Result

struct SignInResult: Equatable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let isNewUser: Bool
}

// MARK: - AuthViewModel

@MainActor
class AuthViewModel: ObservableObject {
    @Published var state: ViewState<Void> = .idle
    @Published var errorMessage: String? = nil
    /// Non-nil once a successful sign-in response has been received.
    /// SignInView observes this to hand off to the AppCoordinator.
    @Published var signedInResult: SignInResult? = nil

    func signInWithApple(
        identityToken: String,
        userIdentifier: String,
        displayName: String?,
        email: String?
    ) async -> SignInResult? {
        state = .loading
        errorMessage = nil

        let request = AppleSignInRequest(
            identityToken: identityToken,
            userIdentifier: userIdentifier,
            displayName: displayName,
            email: email
        )

        do {
            let tokenResponse: TokenResponse = try await NetworkClient.shared.post(
                "/auth/apple",
                body: request
            )
            KeychainHelper.shared.save(tokenResponse.accessToken,  service: "fitandfine", account: "access_token")
            KeychainHelper.shared.save(tokenResponse.refreshToken, service: "fitandfine", account: "refresh_token")
            KeychainHelper.shared.save(userIdentifier,              service: "fitandfine", account: "user_id")
            state = .loaded(())
            let result = SignInResult(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                userId: userIdentifier,
                isNewUser: email != nil
            )
            signedInResult = result
            return result
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Dev Login (Simulator / DEBUG only)

    func devLogin() async -> SignInResult? {
        state = .loading
        errorMessage = nil

        do {
            struct Empty: Encodable {}
            let tokenResponse: TokenResponse = try await NetworkClient.shared.post(
                "/auth/dev-login",
                body: Empty()
            )
            let devUserId = "dev_simulator_user_001"
            KeychainHelper.shared.save(tokenResponse.accessToken,  service: "fitandfine", account: "access_token")
            KeychainHelper.shared.save(tokenResponse.refreshToken, service: "fitandfine", account: "refresh_token")
            KeychainHelper.shared.save(devUserId,                   service: "fitandfine", account: "user_id")
            state = .loaded(())
            let result = SignInResult(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                userId: devUserId,
                isNewUser: false
            )
            signedInResult = result
            return result
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = "Dev login failed: \(error.localizedDescription)\nIs the backend running on localhost:8000?"
            return nil
        }
    }

    func signOut() {
        let refreshToken = KeychainHelper.shared.read(
            service: "fitandfine",
            account: "refresh_token"
        ) ?? ""

        Task {
            _ = try? await NetworkClient.shared.post(
                "/auth/logout",
                body: ["refresh_token": refreshToken]
            ) as MessageResponse
        }

        KeychainHelper.shared.clearAll()
    }
}
