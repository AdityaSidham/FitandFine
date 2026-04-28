import SwiftUI

// MARK: - ProfileView

struct ProfileView: View {
    var coordinator: ProfileCoordinator
    var appCoordinator: AppCoordinator

    // Phase 1: read stored data from Keychain
    private var userId: String {
        KeychainHelper.shared.read(service: "fitandfine", account: "user_id") ?? "—"
    }

    @State private var showSignOutConfirm = false

    var body: some View {
        List {
            // Profile card
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("FitandFine User")
                            .font(.headline)
                        if userId != "—" {
                            Text("ID: \(String(userId.prefix(12)))...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }

            // Account settings
            Section("Account") {
                Button {
                    coordinator.navigate(to: .editProfile)
                } label: {
                    Label("Edit Profile", systemImage: "person.text.rectangle")
                        .foregroundStyle(.primary)
                }

                Button {
                    coordinator.navigate(to: .editGoal)
                } label: {
                    Label("Edit Goal", systemImage: "target")
                        .foregroundStyle(.primary)
                }

                Button {
                    coordinator.navigate(to: .settings)
                } label: {
                    Label("Settings", systemImage: "gear")
                        .foregroundStyle(.primary)
                }
            }

            // App info
            Section("About") {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }

            // Sign out
            Section {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Sign Out",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    private func signOut() {
        // Fire-and-forget logout network call
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
        // Clear keychain and update app state
        appCoordinator.handleSignOut()
    }
}

// MARK: - EditProfileView (stub)

struct EditProfileView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Edit Profile")
                .font(.title2.bold())
            Text("Coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - EditGoalView (stub)

struct EditGoalView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Edit Goal")
                .font(.title2.bold())
            Text("Coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Edit Goal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - SettingsView (stub)

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Settings")
                .font(.title2.bold())
            Text("Coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ProfileView(
            coordinator: ProfileCoordinator(),
            appCoordinator: AppCoordinator()
        )
    }
}
