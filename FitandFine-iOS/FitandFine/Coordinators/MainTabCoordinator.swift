import SwiftUI

struct MainTabView: View {
    let appCoordinator: AppCoordinator

    @StateObject private var dashboardCoordinator = DashboardCoordinator()
    @StateObject private var foodLogCoordinator = FoodLogCoordinator()
    @StateObject private var profileCoordinator = ProfileCoordinator()

    var body: some View {
        TabView {
            DashboardCoordinatorView(coordinator: dashboardCoordinator)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            FoodLogCoordinatorView(coordinator: foodLogCoordinator)
                .tabItem {
                    Label("Food Log", systemImage: "fork.knife")
                }

            ProfileCoordinatorView(coordinator: profileCoordinator, appCoordinator: appCoordinator)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(.green)
    }
}
