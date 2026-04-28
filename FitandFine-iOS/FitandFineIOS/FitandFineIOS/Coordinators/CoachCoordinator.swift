import SwiftUI
import Combine

// MARK: - Navigation Destination

enum CoachDestination: Hashable {
    case chat
    case weeklyReport
    case progressEvaluation
}

// MARK: - Coach Coordinator

@MainActor
final class CoachCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    func navigate(to destination: CoachDestination) {
        path.append(destination)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }
}

// MARK: - Coach Coordinator View

struct CoachCoordinatorView: View {
    @ObservedObject var coordinator: CoachCoordinator
    @StateObject private var viewModel = CoachViewModel()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            CoachHomeView(coordinator: coordinator, viewModel: viewModel)
                .navigationDestination(for: CoachDestination.self) { destination in
                    switch destination {
                    case .chat:
                        CoachChatView(viewModel: viewModel)
                    case .weeklyReport:
                        WeeklyReportView(viewModel: viewModel)
                    case .progressEvaluation:
                        ProgressEvaluationView()
                    }
                }
        }
    }
}

// MARK: - Coach Home View

struct CoachHomeView: View {
    let coordinator: CoachCoordinator
    @ObservedObject var viewModel: CoachViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Hero
                heroCard
                    .entranceAnimation(delay: 0.0)

                // Action cards
                VStack(spacing: 12) {
                    CoachActionCard(icon: "message.fill",            iconColor: DS.Color.accent,
                                   title: "Chat with Coach",
                                   subtitle: "Ask about your diet, get meal ideas, understand your progress") {
                        Haptics.light(); coordinator.navigate(to: .chat)
                    }
                    CoachActionCard(icon: "chart.bar.doc.horizontal", iconColor: .blue,
                                   title: "Weekly Report",
                                   subtitle: "AI analysis of your last 7 days — adherence, patterns, tips") {
                        Haptics.light(); coordinator.navigate(to: .weeklyReport)
                    }
                    CoachActionCard(icon: "scalemass.fill",           iconColor: .orange,
                                   title: "Progress Check",
                                   subtitle: "Plateau detection and personalised calorie adjustments") {
                        Haptics.light(); coordinator.navigate(to: .progressEvaluation)
                    }
                }
                .padding(.horizontal)
                .entranceAnimation(delay: 0.08)

                // Quick prompts
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick questions")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickPrompts, id: \.self) { prompt in
                                Button {
                                    Haptics.select()
                                    viewModel.inputText = prompt
                                    coordinator.navigate(to: .chat)
                                } label: {
                                    Text(prompt)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(DS.Color.surface)
                                        .clipShape(Capsule())
                                        .shadow(color: DS.Shadow.card.color, radius: 6, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
                .entranceAnimation(delay: 0.14)
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DS.Color.accentMid.opacity(0.18), DS.Color.accentDark.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(DS.Color.accent.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 32))
                        .foregroundStyle(DS.Color.accent)
                }
                VStack(spacing: 6) {
                    Text("FitCoach")
                        .font(.title.bold())
                    Text("AI-powered nutrition coaching\npersonalised to your food log")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 28)
        }
        .padding(.horizontal)
    }

    private let quickPrompts = [
        "Why am I not losing weight?",
        "Am I hitting my protein?",
        "Suggest a high-protein lunch",
        "How was my week?",
        "Help me reduce sugar",
    ]
}

// MARK: - Action Card

private struct CoachActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.13))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(DS.Anim.springFast, value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}
