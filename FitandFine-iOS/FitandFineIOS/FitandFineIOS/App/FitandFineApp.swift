import SwiftUI
import SwiftData

@main
struct FitandFineApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var healthKit = HealthKitManager.shared

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: appCoordinator)
                .modelContainer(for: [
                    CachedFoodItem.self,
                    LocalDailyLog.self,
                    CachedUserProfile.self,
                    CachedGoal.self,
                ])
                .environmentObject(healthKit)
                .task {
                    // Request HealthKit auth once the app is running
                    // (only fires the system prompt on first launch)
                    if HealthKitManager.isAvailable && !healthKit.hasRequestedAuthorization {
                        await healthKit.requestAuthorization()
                    } else if HealthKitManager.isAvailable {
                        await healthKit.refreshAll()
                    }
                }
        }
    }
}
