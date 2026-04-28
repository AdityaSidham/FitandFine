import SwiftUI
import AuthenticationServices

struct SignInView: View {
    var coordinator: AuthCoordinator
    @StateObject private var viewModel = AuthViewModel()

    @State private var logoAppeared   = false
    @State private var titleAppeared  = false
    @State private var buttonAppeared = false

    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    DS.Color.accentMid.opacity(0.06),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo + brand ───────────────────────────────────────────
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(DS.Color.accent.opacity(0.12))
                            .frame(width: 110, height: 110)
                        Circle()
                            .fill(DS.Color.accent.opacity(0.07))
                            .frame(width: 140, height: 140)
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(DS.Color.accent)
                            .shadow(color: DS.Color.accent.opacity(0.30), radius: 16, y: 6)
                    }
                    .scaleEffect(logoAppeared ? 1 : 0.55)
                    .opacity(logoAppeared ? 1 : 0)

                    VStack(spacing: 8) {
                        Text("FitandFine")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Your intelligent nutrition companion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(titleAppeared ? 1 : 0)
                    .offset(y: titleAppeared ? 0 : 14)
                }

                Spacer()

                // ── Sign-in section ────────────────────────────────────────
                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                    .padding(.horizontal, 28)

                    Text("We'll never share your data with third parties.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)

                    // ── Dev Login (DEBUG only) ─────────────────────────────
                    #if DEBUG
                    VStack(spacing: 10) {
                        HStack {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 0.5)
                            Text("DEV")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 0.5)
                        }
                        .padding(.horizontal, 28)

                        Button {
                            Haptics.medium()
                            Task {
                                if let result = await viewModel.devLogin() {
                                    coordinator.appCoordinator.handleSignIn(
                                        accessToken: result.accessToken,
                                        refreshToken: result.refreshToken,
                                        userId: result.userId,
                                        isNewUser: result.isNewUser
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "hammer.fill")
                                Text("Dev Login (Simulator)")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.indigo, Color.indigo.opacity(0.8)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        }
                        .padding(.horizontal, 28)

                        Text("Bypasses OAuth — development only")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    #endif
                }
                .opacity(buttonAppeared ? 1 : 0)
                .offset(y: buttonAppeared ? 0 : 20)
                .padding(.bottom, 52)
            }

            // ── Loading overlay ────────────────────────────────────────────
            if viewModel.state.isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                            .tint(.white)
                        Text("Signing in…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign In Failed", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .onAppear { triggerEntrance() }
    }

    private func triggerEntrance() {
        withAnimation(DS.Anim.entrance) { logoAppeared = true }
        withAnimation(DS.Anim.entrance.delay(0.15)) { titleAppeared = true }
        withAnimation(DS.Anim.entrance.delay(0.28)) { buttonAppeared = true }
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
                if let result = await viewModel.signInWithApple(
                    identityToken: identityToken,
                    userIdentifier: userIdentifier,
                    displayName: displayName,
                    email: email
                ) {
                    coordinator.appCoordinator.handleSignIn(
                        accessToken: result.accessToken,
                        refreshToken: result.refreshToken,
                        userId: result.userId,
                        isNewUser: result.isNewUser
                    )
                }
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
