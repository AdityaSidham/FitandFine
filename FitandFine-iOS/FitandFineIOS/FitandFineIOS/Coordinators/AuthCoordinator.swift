import SwiftUI
import Combine

// MARK: - Navigation Destination

enum AuthDestination: Hashable {
    case signIn
    case welcome
}

// MARK: - Auth Coordinator

@MainActor
final class AuthCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    let appCoordinator: AppCoordinator

    init(appCoordinator: AppCoordinator) {
        self.appCoordinator = appCoordinator
    }

    func navigate(to destination: AuthDestination) {
        path.append(destination)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func popToRoot() {
        path = NavigationPath()
    }
}

// MARK: - Auth Coordinator View

struct AuthCoordinatorView: View {
    @ObservedObject var coordinator: AuthCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            WelcomeView(coordinator: coordinator)
                .navigationDestination(for: AuthDestination.self) { destination in
                    switch destination {
                    case .signIn:
                        SignInView(coordinator: coordinator)
                    case .welcome:
                        WelcomeView(coordinator: coordinator)
                    }
                }
        }
    }
}
