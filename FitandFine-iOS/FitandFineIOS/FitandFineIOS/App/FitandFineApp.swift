import SwiftUI
import SwiftData

@main
struct FitandFineApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var healthKit = HealthKitManager.shared

    private static var container: ModelContainer = {
        let schema = Schema([
            CachedFoodItem.self,
            LocalDailyLog.self,
            CachedUserProfile.self,
            CachedGoal.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema mismatch from a previous build — wipe and recreate
            print("SwiftData schema error, resetting store: \(error)")
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [inMemoryConfig])
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: appCoordinator)
                .modelContainer(Self.container)
                .environmentObject(healthKit)
                .task {
                    guard HealthKitManager.isAvailable else { return }
                    if !healthKit.hasRequestedAuthorization {
                        await healthKit.requestAuthorization()
                    } else {
                        await healthKit.refreshAll()
                    }
                }
        }
    }
}
