import SwiftUI
import Combine

// MARK: - ProfileView

struct ProfileView: View {
    var coordinator: ProfileCoordinator
    var appCoordinator: AppCoordinator

    @StateObject private var vm = ProfileViewModel()
    @State private var showSignOutConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                // ── Profile hero ──────────────────────────────────────────
                profileHeroCard
                    .entranceAnimation(delay: 0.0)

                // ── Goal macros ───────────────────────────────────────────
                if let goal = vm.goal {
                    goalMacroCard(goal)
                        .entranceAnimation(delay: 0.05)
                }

                // ── Navigation rows ───────────────────────────────────────
                VStack(spacing: 0) {
                    navRow(icon: "person.text.rectangle.fill", iconColor: DS.Color.accent,
                           title: "Edit Profile", subtitle: "Name, age, height") {
                        coordinator.navigate(to: .editProfile)
                    }
                    Divider().padding(.leading, 60)

                    navRow(icon: "target", iconColor: .blue,
                           title: "Edit Goal", subtitle: "Calorie target, goal type") {
                        coordinator.navigate(to: .editGoal)
                    }
                    Divider().padding(.leading, 60)

                    navRow(icon: "scalemass.fill", iconColor: .orange,
                           title: "Log Weight", subtitle: "Track your progress") {
                        coordinator.navigate(to: .weightLog)
                    }
                    Divider().padding(.leading, 60)

                    navRow(icon: "gear", iconColor: .secondary,
                           title: "Settings", subtitle: "Notifications, Apple Health") {
                        coordinator.navigate(to: .settings)
                    }
                }
                .appCard(0)
                .entranceAnimation(delay: 0.10)

                // ── Sign out ──────────────────────────────────────────────
                Button {
                    Haptics.medium()
                    showSignOutConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .entranceAnimation(delay: 0.14)

                Text("FitandFine v1.0.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Profile hero card

    private var profileHeroCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DS.Color.accentMid.opacity(0.20), DS.Color.accent.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(DS.Color.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                if vm.isLoading {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 130, height: 16)
                        .shimmer()
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 11)
                        .shimmer()
                } else {
                    Text(vm.user?.displayName ?? "FitandFine User")
                        .font(.title3.bold())
                    if let goal = vm.goal {
                        PillLabel(
                            text: "\(goal.goalType.replacingOccurrences(of: "_", with: " ").capitalized) · \(goal.calorieTarget ?? 2000) kcal",
                            color: DS.Color.accent,
                            size: .caption
                        )
                    }
                }
            }

            Spacer()
        }
        .appCard(16)
    }

    // MARK: - Goal macro card

    private func goalMacroCard(_ goal: GoalResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Targets")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            HStack(spacing: 0) {
                macroTarget("\(goal.calorieTarget ?? 0)", "kcal", "Calories", DS.Color.accent)
                Divider().frame(height: 44)
                macroTarget(goal.proteinG.map { "\(Int($0))" } ?? "—", "g", "Protein", DS.Color.protein)
                Divider().frame(height: 44)
                macroTarget(goal.carbG.map    { "\(Int($0))" } ?? "—", "g", "Carbs",   DS.Color.carbs)
                Divider().frame(height: 44)
                macroTarget(goal.fatG.map     { "\(Int($0))" } ?? "—", "g", "Fat",     DS.Color.fat)
            }
            .background(Color(.systemGray5).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        }
        .appCard(16)
    }

    private func macroTarget(_ value: String, _ unit: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Nav row

    private func navRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.13))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func signOut() {
        let refreshToken = KeychainHelper.shared.read(service: "fitandfine", account: "refresh_token") ?? ""
        Task {
            _ = try? await NetworkClient.shared.post(
                "/auth/logout", body: ["refresh_token": refreshToken]
            ) as MessageResponse
        }
        appCoordinator.handleSignOut()
    }
}

// MARK: - Profile ViewModel

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: UserResponse? = nil
    @Published var goal: GoalResponse? = nil
    @Published var isLoading = false

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        async let userResult: UserResponse = NetworkClient.shared.get("/users/me")
        async let goalResult: GoalResponse = NetworkClient.shared.get("/goals/")
        user = try? await userResult
        goal = try? await goalResult
    }
}

// MARK: - EditProfileView

struct EditProfileView: View {
    @StateObject private var vm = EditProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Personal Information") {
                LabeledContent("Name") {
                    TextField("Display name", text: $vm.displayName)
                        .multilineTextAlignment(.trailing)
                }
                DatePicker("Date of Birth", selection: $vm.dateOfBirth,
                           in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                           displayedComponents: .date)
                Picker("Biological Sex", selection: $vm.sex) {
                    Text("Male").tag("male")
                    Text("Female").tag("female")
                }
                LabeledContent("Height (cm)") {
                    TextField("e.g. 170", text: $vm.heightCm)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Activity") {
                Picker("Activity Level", selection: $vm.activityLevel) {
                    Text("Sedentary").tag("sedentary")
                    Text("Light").tag("light")
                    Text("Moderate").tag("moderate")
                    Text("Active").tag("active")
                    Text("Very Active").tag("very_active")
                }
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { Task { await vm.save(); if vm.saved { dismiss() } } }
                    .disabled(vm.isLoading)
                    .bold()
            }
        }
        .task { await vm.load() }
        .overlay {
            if vm.isLoading { ProgressView() }
        }
    }
}

@MainActor
class EditProfileViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var dateOfBirth = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @Published var sex = "male"
    @Published var heightCm = ""
    @Published var activityLevel = "moderate"
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var saved = false

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let user: UserResponse = try? await NetworkClient.shared.get("/users/me") else { return }
        displayName = user.displayName ?? ""
        sex = user.sex ?? "male"
        activityLevel = user.activityLevel ?? "moderate"
        if let h = user.heightCm { heightCm = String(format: "%.0f", h) }
        if let dob = user.dateOfBirth {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            dateOfBirth = f.date(from: dob) ?? dateOfBirth
        }
    }

    func save() async {
        isLoading = true
        defer { isLoading = false }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let body = UserProfileUpdate(
            displayName: displayName.isEmpty ? nil : displayName,
            dateOfBirth: f.string(from: dateOfBirth),
            sex: sex,
            heightCm: Double(heightCm),
            activityLevel: activityLevel,
            timezone: TimeZone.current.identifier
        )
        do {
            let _: UserResponse = try await NetworkClient.shared.put("/users/me", body: body)
            saved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - EditGoalView

struct EditGoalView: View {
    @StateObject private var vm = EditGoalViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Goal Type") {
                Picker("Goal", selection: $vm.goalType) {
                    Text("Lose Weight").tag("lose_weight")
                    Text("Maintain").tag("maintain")
                    Text("Gain Muscle").tag("gain_muscle")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Targets") {
                LabeledContent("Target Weight (kg)") {
                    TextField("Optional", text: $vm.targetWeightKg)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Calorie Override") {
                    TextField("Auto-computed", text: $vm.calorieOverride)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                Text("Leaving Calorie Override blank uses Mifflin-St Jeor BMR × activity level.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .navigationTitle("Edit Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { Task { await vm.save(); if vm.saved { dismiss() } } }
                    .disabled(vm.isLoading)
                    .bold()
            }
        }
        .task { await vm.load() }
        .overlay {
            if vm.isLoading { ProgressView() }
        }
    }
}

@MainActor
class EditGoalViewModel: ObservableObject {
    @Published var goalType = "lose_weight"
    @Published var targetWeightKg = ""
    @Published var calorieOverride = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var saved = false

    func load() async {
        guard let goal: GoalResponse = try? await NetworkClient.shared.get("/goals/") else { return }
        goalType = goal.goalType
        if let tw = goal.targetWeightKg { targetWeightKg = String(format: "%.1f", tw) }
        if let cal = goal.calorieTarget { calorieOverride = String(cal) }
    }

    func save() async {
        isLoading = true
        defer { isLoading = false }
        let body = CreateGoalRequest(
            goalType: goalType,
            targetWeightKg: Double(targetWeightKg),
            weeklyWeightChangeTargetKg: weeklyChange,
            calorieTarget: Int(calorieOverride)
        )
        do {
            let _: GoalResponse = try await NetworkClient.shared.post("/goals/", body: body)
            saved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var weeklyChange: Double? {
        switch goalType {
        case "lose_weight": return -0.5
        case "gain_muscle": return 0.25
        default: return nil
        }
    }
}

// MARK: - WeightLogView

struct WeightLogView: View {
    @StateObject private var vm = WeightLogViewModel()
    @EnvironmentObject private var healthKit: HealthKitManager

    var body: some View {
        List {
            // Import from HealthKit banner
            if HealthKitManager.isAvailable && healthKit.latestWeightKg != nil {
                Section {
                    Button {
                        Task { await vm.importFromHealthKit(healthKit: healthKit) }
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill").foregroundStyle(.red)
                            Text("Import latest from Apple Health")
                            Spacer()
                            if let kg = healthKit.latestWeightKg {
                                Text(String(format: "%.1f kg", kg))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Log today's weight
            Section("Log Weight") {
                HStack(spacing: 16) {
                    TextField("kg", text: $vm.weightInput)
                        .keyboardType(.decimalPad)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.green)
                        .frame(width: 100)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kilograms")
                            .font(.subheadline.bold())
                        if let latest = vm.history?.currentWeightKg {
                            Text("Last: \(String(format: "%.1f", latest)) kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        Task { await vm.logWeight(healthKit: healthKit) }
                    } label: {
                        if vm.isSaving {
                            ProgressView()
                        } else {
                            Text("Log")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(DS.Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                        }
                    }
                    .disabled(vm.isSaving || vm.weightInput.isEmpty)
                }
                .padding(.vertical, 8)
            }

            // Trend summary
            if let hist = vm.history, !hist.entries.isEmpty {
                Section("Trend") {
                    if let rate = hist.weeklyRateKg {
                        HStack {
                            Image(systemName: rate < 0 ? "arrow.down.circle.fill" : (rate > 0 ? "arrow.up.circle.fill" : "equal.circle.fill"))
                                .foregroundStyle(rate < 0 ? .orange : (rate > 0 ? .green : .secondary))
                            Text(String(format: "%+.2f kg/week", rate))
                                .font(.subheadline.bold())
                            Spacer()
                            Text(hist.trendDirection?.capitalized ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let total = hist.totalChangeKg {
                        LabeledContent("Total change", value: String(format: "%+.1f kg", total))
                    }
                }

                Section("History") {
                    ForEach(hist.entries.reversed().prefix(30)) { entry in
                        HStack {
                            Text(formattedDate(entry.logDate))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f kg", entry.weightKg))
                                .font(.subheadline.bold())
                        }
                    }
                }
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .navigationTitle("Weight Log")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.loadHistory()
            await healthKit.refreshAll()
        }
        .alert("Logged!", isPresented: $vm.showSuccess) {
            Button("OK") {}
        } message: {
            Text("Weight entry saved.")
        }
    }

    private func formattedDate(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return str }
        let out = DateFormatter(); out.dateFormat = "MMM d, yyyy"
        return out.string(from: d)
    }
}

@MainActor
class WeightLogViewModel: ObservableObject {
    @Published var weightInput = ""
    @Published var history: WeightHistoryResponse? = nil
    @Published var isSaving = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showSuccess = false

    func loadHistory() async {
        isLoading = true
        defer { isLoading = false }
        history = try? await NetworkClient.shared.get("/weight/history?days=90")
    }

    func logWeight(healthKit: HealthKitManager? = nil) async {
        guard let weight = Double(weightInput), weight > 0 else { return }
        isSaving = true
        defer { isSaving = false }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let body = AddWeightLogRequest(
            logDate: f.string(from: Date()),
            weightKg: weight,
            bodyFatPct: nil,
            measurementSource: "manual"
        )
        do {
            let _: WeightLogResponse = try await NetworkClient.shared.post("/weight/", body: body)
            // Mirror to Apple Health
            try? await healthKit?.writeWeight(kg: weight)
            weightInput = ""
            showSuccess = true
            await loadHistory()
        } catch NetworkError.conflict(_) {
            errorMessage = "You already logged weight today. Go to history to update it."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Pre-fill weight input from the latest HealthKit body mass reading,
    /// then log it to the backend automatically.
    func importFromHealthKit(healthKit: HealthKitManager) async {
        guard let kg = healthKit.latestWeightKg else { return }
        weightInput = String(format: "%.1f", kg)
        await logWeight(healthKit: nil)  // already came from HK — don't write back
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("reminderHour") private var reminderHour = 20
    @EnvironmentObject private var healthKit: HealthKitManager

    var body: some View {
        Form {
            // Apple Health
            Section("Apple Health") {
                if HealthKitManager.isAvailable {
                    if healthKit.hasRequestedAuthorization {
                        HStack {
                            Image(systemName: "heart.fill").foregroundStyle(.red)
                            Text("Connected")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                        Button("Re-authorise in Health App") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.subheadline)
                    } else {
                        Button {
                            Task { await healthKit.requestAuthorization() }
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill").foregroundStyle(.red)
                                Text("Connect Apple Health")
                            }
                        }
                    }
                } else {
                    Label("Not available on this device", systemImage: "heart.slash")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notifications") {
                Toggle("Daily Reminder", isOn: $notificationsEnabled)
                if notificationsEnabled {
                    Stepper("Reminder at \(reminderHour):00", value: $reminderHour, in: 6...22)
                }
            }

            Section("Display") {
                LabeledContent("Units", value: "Metric (kg, cm)")
                LabeledContent("Language", value: Locale.current.language.languageCode?.identifier ?? "en")
            }

            Section("Data") {
                Button(role: .destructive) {
                    // placeholder: delete account flow
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
            }

            Section("About") {
                LabeledContent("App Version", value: "1.0.0")
                LabeledContent("Backend", value: "FastAPI + PostgreSQL")
                LabeledContent("AI", value: "Google Gemini")
            }
        }
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
