import SwiftUI
import Combine

class ProfileCoordinator: ObservableObject {
    enum Destination: Hashable {
        case editProfile
        case editGoal
        case weightLog
        case settings
    }

    @Published var path = NavigationPath()

    func navigate(to destination: Destination) {
        path.append(destination)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }
}

struct ProfileCoordinatorView: View {
    @ObservedObject var coordinator: ProfileCoordinator
    var appCoordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ProfileView(coordinator: coordinator, appCoordinator: appCoordinator)
                .navigationDestination(for: ProfileCoordinator.Destination.self) { destination in
                    switch destination {
                    case .editProfile:
                        EditProfileView()
                    case .editGoal:
                        EditGoalView()
                    case .weightLog:
                        WeightLogView()
                    case .settings:
                        SettingsView()
                    }
                }
        }
    }
}
