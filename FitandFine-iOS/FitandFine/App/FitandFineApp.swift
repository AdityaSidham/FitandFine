import SwiftUI
import SwiftData

@main
struct FitandFineApp: App {
    @StateObject private var appCoordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: appCoordinator)
                .modelContainer(for: [
                    CachedFoodItem.self,
                    LocalDailyLog.self,
                    CachedUserProfile.self,
                    CachedGoal.self,
                ])
        }
    }
}
