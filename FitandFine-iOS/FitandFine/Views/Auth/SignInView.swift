import SwiftUI
import AuthenticationServices

struct SignInView: View {
    var coordinator: AuthCoordinator
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo + title
                VStack(spacing: 16) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)
                        .shadow(color: .green.opacity(0.25), radius: 12, y: 6)

                    Text("FitandFine")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Sign in to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Sign In with Apple
                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)

                    Text("We'll never share your data with third parties.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // ── Dev Login (DEBUG simulator builds only) ──────────────
                    #if DEBUG
                    VStack(spacing: 8) {
                        Divider().padding(.horizontal, 32)

                        Button(action: {
                            Task { await viewModel.devLogin() }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "hammer.fill")
                                Text("Dev Login (Simulator)")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 32)
                        }

                        Text("Bypasses OAuth — development only")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    #endif
                }
                .padding(.bottom, 52)
            }

            // Loading overlay
            if viewModel.state.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.signedInResult) { _, result in
            if let result {
                coordinator.appCoordinator.handleSignIn(
                    accessToken: result.accessToken,
                    refreshToken: result.refreshToken,
                    userId: result.userId,
                    isNewUser: result.isNewUser
                )
            }
        }
        .alert("Sign In Failed", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                viewModel.errorMessage = "Failed to retrieve Apple ID credentials."
                return
            }

            let userIdentifier = credential.user
            let displayName: String? = {
                guard let name = credential.fullName else { return nil }
                let formatted = PersonNameComponentsFormatter().string(from: name)
                return formatted.isEmpty ? nil : formatted
            }()
            let email = credential.email

            Task {
                await viewModel.signInWithApple(
                    identityToken: identityToken,
                    userIdentifier: userIdentifier,
                    displayName: displayName,
                    email: email
                )
            }

        case .failure(let error):
            let asError = error as? ASAuthorizationError
            if asError?.code != .canceled {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignInView(coordinator: AuthCoordinator(appCoordinator: AppCoordinator()))
    }
}
