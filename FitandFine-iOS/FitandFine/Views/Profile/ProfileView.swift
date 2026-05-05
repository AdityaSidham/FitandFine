import SwiftUI

// MARK: - ProfileView

struct ProfileView: View {
    var coordinator: ProfileCoordinator
    var appCoordinator: AppCoordinator

    private var userId: String {
        KeychainHelper.shared.read(service: "fitandfine", account: "user_id") ?? "—"
    }

    @State private var showSignOutConfirm = false

    var body: some View {
        ZStack {
            Color.ffWarmWhite.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    profileCard
                    accountSection
                    aboutSection
                    signOutSection
                }
                .padding(.horizontal, DS.paddingPage)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Profile Card

    @ViewBuilder
    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.ffSage, Color.ffTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("FitandFine User")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                if userId != "—" {
                    Text("ID · \(String(userId.prefix(10)))…")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.ffText3)
                }
            }

            Spacer()
        }
        .ffCard()
    }

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        VStack(spacing: 0) {
            ProfileSectionHeader(title: "Account")

            VStack(spacing: 0) {
                ProfileRow(icon: "person.text.rectangle", label: "Edit Profile", color: Color.ffSage) {
                    coordinator.navigate(to: .editProfile)
                }
                Divider().padding(.leading, 52)
                ProfileRow(icon: "target", label: "Edit Goal", color: Color.ffTeal) {
                    coordinator.navigate(to: .editGoal)
                }
                Divider().padding(.leading, 52)
                ProfileRow(icon: "gear", label: "Settings", color: Color.ffText2) {
                    coordinator.navigate(to: .settings)
                }
            }
            .ffCardNoPad()
        }
    }

    // MARK: - About Section

    @ViewBuilder
    private var aboutSection: some View {
        VStack(spacing: 0) {
            ProfileSectionHeader(title: "About")

            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.ffMintLight)
                        .frame(width: 30, height: 30)
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.ffSage)
                }
                Text("Version")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                Spacer()
                Text("1.0.0")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Color.ffText2)
            }
            .padding(.horizontal, DS.paddingCard)
            .padding(.vertical, 14)
            .ffCardNoPad()
        }
    }

    // MARK: - Sign Out Section

    @ViewBuilder
    private var signOutSection: some View {
        Button {
            showSignOutConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15))
                Text("Sign Out")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.ffFat)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.ffFat.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DS.cornerCard))
        }
    }

    // MARK: - Sign Out Logic

    private func signOut() {
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
        appCoordinator.handleSignOut()
    }
}

// MARK: - Reusable Profile Components

private struct ProfileSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ffText3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.bottom, 6)
    }
}

private struct ProfileRow: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Color.ffText1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.ffText3)
            }
            .padding(.horizontal, DS.paddingCard)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Stub Views

struct EditProfileView: View {
    var body: some View {
        stubContent(icon: "person.text.rectangle.fill", title: "Edit Profile", color: Color.ffSage)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct EditGoalView: View {
    var body: some View {
        stubContent(icon: "target", title: "Edit Goal", color: Color.ffTeal)
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView: View {
    var body: some View {
        stubContent(icon: "gear.circle.fill", title: "Settings", color: Color.ffText2)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private func stubContent(icon: String, title: String, color: Color) -> some View {
    ZStack {
        Color.ffWarmWhite.ignoresSafeArea()
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ffText1)
            Text("Coming soon")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.ffText3)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(coordinator: ProfileCoordinator(), appCoordinator: AppCoordinator())
    }
}
