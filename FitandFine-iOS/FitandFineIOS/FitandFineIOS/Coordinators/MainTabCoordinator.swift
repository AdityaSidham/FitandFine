import SwiftUI
import Combine

extension Notification.Name {
    static let switchToFoodLogTab = Notification.Name("switchToFoodLogTab")
}

struct MainTabView: View {
    let appCoordinator: AppCoordinator

    @StateObject private var dashboardCoordinator = DashboardCoordinator()
    @StateObject private var foodLogCoordinator   = FoodLogCoordinator()
    @StateObject private var coachCoordinator     = CoachCoordinator()
    @StateObject private var profileCoordinator   = ProfileCoordinator()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardCoordinatorView(coordinator: dashboardCoordinator)
                .tabItem { Label("Dashboard", systemImage: selectedTab == 0 ? "chart.bar.fill" : "chart.bar") }
                .tag(0)

            FoodLogCoordinatorView(coordinator: foodLogCoordinator)
                .tabItem { Label("Food Log", systemImage: selectedTab == 1 ? "fork.knife.circle.fill" : "fork.knife") }
                .tag(1)

            CoachCoordinatorView(coordinator: coachCoordinator)
                .tabItem { Label("Coach", systemImage: selectedTab == 2 ? "brain.head.profile" : "brain") }
                .tag(2)

            AnalyticsCoordinatorView()
                .tabItem { Label("Analytics", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(3)

            ProfileCoordinatorView(coordinator: profileCoordinator, appCoordinator: appCoordinator)
                .tabItem { Label("Profile", systemImage: selectedTab == 4 ? "person.fill" : "person") }
                .tag(4)
        }
        .tint(DS.Color.accent)
        .onReceive(NotificationCenter.default.publisher(for: .switchToFoodLogTab)) { _ in
            withAnimation(DS.Anim.smooth) { selectedTab = 1 }
            Haptics.select()
        }
    }
}
