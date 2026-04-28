import SwiftUI

// MARK: - Onboarding Coordinator View (multi-step)

struct OnboardingCoordinatorView: View {
    let userId: String
    let appCoordinator: AppCoordinator

    // Step tracking (0 = profile, 1 = goal, 2 = preferences)
    @State private var currentStep = 0
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    // ── Step 1: Profile ────────────────────────────────────────────────
    @State private var displayName = ""
    @State private var dateOfBirth = Calendar.current.date(
        byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var sex = "male"
    @State private var heightCm = ""
    @State private var activityLevel = "moderate"

    // ── Step 2: Goal ───────────────────────────────────────────────────
    @State private var goalType = "lose_weight"
    @State private var targetWeightKg = ""
    @State private var currentWeightKg = ""

    // ── Step 3: Preferences ────────────────────────────────────────────
    @State private var selectedRestrictions: Set<String> = []
    @State private var selectedAllergies: Set<String> = []

    private let totalSteps = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader

                TabView(selection: $currentStep) {
                    profileStep.tag(0)
                    goalStep.tag(1)
                    preferencesStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentStep ? Color.green : Color(.systemGray5))
                        .frame(height: 4)
                        .animation(.easeInOut, value: currentStep)
                }
            }
            .padding(.horizontal, 24)

            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: return "Your Profile"
        case 1: return "Your Goal"
        default: return "Preferences"
        }
    }

    // MARK: - Step 1: Profile

    private var profileStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("Tell us about yourself")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("This helps us calculate your personalised calorie target.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                // Form
                VStack(spacing: 20) {
                    // Display name
                    FormField(label: "Name (optional)") {
                        TextField("Your name", text: $displayName)
                            .textContentType(.name)
                    }

                    // Date of birth
                    FormField(label: "Date of Birth") {
                        DatePicker("", selection: $dateOfBirth,
                                   in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                                   displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Sex
                    FormField(label: "Biological Sex") {
                        Picker("Sex", selection: $sex) {
                            Text("Male").tag("male")
                            Text("Female").tag("female")
                        }
                        .pickerStyle(.segmented)
                    }

                    // Height
                    FormField(label: "Height (cm)") {
                        TextField("e.g. 170", text: $heightCm)
                            .keyboardType(.decimalPad)
                    }

                    // Activity level
                    FormField(label: "Activity Level") {
                        Picker("Activity", selection: $activityLevel) {
                            Text("Sedentary").tag("sedentary")
                            Text("Light").tag("light")
                            Text("Moderate").tag("moderate")
                            Text("Active").tag("active")
                            Text("Very Active").tag("very_active")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)

                // CTA
                PrimaryButton(title: "Continue →", isLoading: isLoading) {
                    Task { await submitProfile() }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Step 2: Goal

    private var goalStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("Set your goal")
                        .font(.title2.bold())
                    Text("We'll compute your daily calorie target automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                VStack(spacing: 20) {
                    // Goal type
                    FormField(label: "Goal") {
                        VStack(spacing: 10) {
                            ForEach(GoalTypeOption.all, id: \.id) { option in
                                GoalTypeRow(option: option, selected: goalType == option.id) {
                                    goalType = option.id
                                }
                            }
                        }
                    }

                    // Current weight
                    FormField(label: "Current Weight (kg)") {
                        TextField("e.g. 75.0", text: $currentWeightKg)
                            .keyboardType(.decimalPad)
                    }

                    // Target weight (optional)
                    FormField(label: "Target Weight (kg) — optional") {
                        TextField("e.g. 68.0", text: $targetWeightKg)
                            .keyboardType(.decimalPad)
                    }
                }
                .padding(.horizontal, 24)

                PrimaryButton(title: "Continue →", isLoading: isLoading) {
                    Task { await submitGoal() }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Step 3: Preferences

    private var preferencesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("Dietary preferences")
                        .font(.title2.bold())
                    Text("Help us filter recommendations to fit your needs. You can change these any time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 20) {
                    FormField(label: "Dietary Restrictions") {
                        TagGrid(
                            options: DietaryOption.restrictions,
                            selected: $selectedRestrictions
                        )
                    }

                    FormField(label: "Allergies") {
                        TagGrid(
                            options: DietaryOption.allergies,
                            selected: $selectedAllergies
                        )
                    }
                }
                .padding(.horizontal, 24)

                PrimaryButton(title: "Let's Go!", isLoading: isLoading) {
                    Task { await submitPreferences() }
                }
                .padding(.horizontal, 24)

                Button("Skip for now") {
                    appCoordinator.handleOnboardingComplete(userId: userId)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Networking

    private func submitProfile() async {
        isLoading = true
        defer { isLoading = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dob = formatter.string(from: dateOfBirth)

        let body = UserProfileUpdate(
            displayName: displayName.isEmpty ? nil : displayName,
            dateOfBirth: dob,
            sex: sex,
            heightCm: Double(heightCm),
            activityLevel: activityLevel,
            timezone: TimeZone.current.identifier
        )
        do {
            let _: UserResponse = try await NetworkClient.shared.put("/users/me", body: body)
            withAnimation { currentStep = 1 }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitGoal() async {
        isLoading = true
        defer { isLoading = false }

        // Log current weight first (if provided) so the goal endpoint can compute TDEE
        if let weight = Double(currentWeightKg), weight > 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())
            let weightBody = AddWeightLogRequest(
                logDate: today,
                weightKg: weight,
                bodyFatPct: nil,
                measurementSource: "manual"
            )
            _ = try? await NetworkClient.shared.post("/weight/", body: weightBody) as WeightLogResponse
        }

        let weeklyTarget: Double? = {
            switch goalType {
            case "lose_weight": return -0.5
            case "gain_muscle": return 0.25
            default: return nil
            }
        }()

        let body = CreateGoalRequest(
            goalType: goalType,
            targetWeightKg: Double(targetWeightKg),
            weeklyWeightChangeTargetKg: weeklyTarget,
            calorieTarget: nil
        )
        do {
            let _: GoalResponse = try await NetworkClient.shared.post("/goals/", body: body)
            withAnimation { currentStep = 2 }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitPreferences() async {
        isLoading = true
        defer { isLoading = false }

        let body = UserPreferencesUpdate(
            dietaryRestrictions: selectedRestrictions.isEmpty ? nil : Array(selectedRestrictions),
            allergies: selectedAllergies.isEmpty ? nil : Array(selectedAllergies),
            preferredCuisine: nil,
            budgetPerMealUsd: nil
        )
        do {
            let _: UserResponse = try await NetworkClient.shared.put("/users/me/preferences", body: body)
            appCoordinator.handleOnboardingComplete(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared Form Components

private struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            if isLoading {
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.green)
        .disabled(isLoading)
    }
}

// MARK: - Goal Type Row

private struct GoalTypeOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String

    static let all: [GoalTypeOption] = [
        .init(id: "lose_weight", title: "Lose Weight",    subtitle: "Calorie deficit for fat loss", icon: "arrow.down.circle.fill"),
        .init(id: "maintain",    title: "Maintain",       subtitle: "Keep current weight steady",   icon: "equal.circle.fill"),
        .init(id: "gain_muscle", title: "Gain Muscle",    subtitle: "Calorie surplus for growth",   icon: "arrow.up.circle.fill"),
    ]
}

private struct GoalTypeRow: View {
    let option: GoalTypeOption
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: option.icon)
                    .font(.title2)
                    .foregroundStyle(selected ? .green : .secondary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? .green : .secondary)
            }
            .padding(12)
            .background(selected ? Color.green.opacity(0.08) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.green : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Grid

private struct TagGrid: View {
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                TagChip(title: option, isSelected: selected.contains(option)) {
                    if selected.contains(option) {
                        selected.remove(option)
                    } else {
                        selected.insert(option)
                    }
                }
            }
        }
    }
}

private struct TagChip: View {
    let title: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.green : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Dietary Options

private enum DietaryOption {
    static let restrictions = [
        "Vegetarian", "Vegan", "Pescatarian",
        "Gluten-Free", "Dairy-Free", "Halal",
        "Kosher", "Keto", "Paleo", "Low-FODMAP",
    ]
    static let allergies = [
        "Peanuts", "Tree Nuts", "Milk", "Eggs",
        "Wheat", "Soy", "Fish", "Shellfish", "Sesame",
    ]
}
