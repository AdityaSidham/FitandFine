import SwiftUI

// MARK: - Navigation Destination

enum DashboardDestination: Hashable {
    case scanner
    case foodSearch
    case foodDetail(foodId: String)
}

// MARK: - Dashboard Coordinator

@MainActor
final class DashboardCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    func navigate(to destination: DashboardDestination) {
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

// MARK: - Dashboard Coordinator View

struct DashboardCoordinatorView: View {
    @ObservedObject var coordinator: DashboardCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            DashboardView(coordinator: coordinator)
                .navigationDestination(for: DashboardDestination.self) { destination in
                    switch destination {
                    case .scanner:
                        BarcodeScannerView(
                            viewModel: ScannerViewModel(),
                            onAddToLog: { _, _ in coordinator.pop() }
                        )
                    case .foodSearch:
                        FoodSearchNavigationView(coordinator: coordinator)
                    case .foodDetail(let foodId):
                        FoodDetailPlaceholderView(foodId: foodId)
                    }
                }
        }
    }
}

// MARK: - Supporting Views

struct FoodSearchNavigationView: View {
    let coordinator: DashboardCoordinator
    @StateObject private var viewModel = FoodLogViewModel()
    @State private var query = ""

    var body: some View {
        List {
            ForEach(viewModel.searchResults) { food in
                Button {
                    coordinator.navigate(to: .foodDetail(foodId: food.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).font(.headline)
                        if let brand = food.brand {
                            Text(brand).font(.caption).foregroundStyle(.secondary)
                        }
                        if let cal = food.calories {
                            Text("\(Int(cal)) kcal").font(.caption2).foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Search Foods")
        .searchable(text: $query, prompt: "Search foods...")
        .onChange(of: query) { _, newValue in
            Task { await viewModel.searchFoods(query: newValue) }
        }
    }
}

struct FoodDetailPlaceholderView: View {
    let foodId: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundStyle(.green)
            Text("Food Detail")
                .font(.title2.bold())
            Text("Food ID: \(foodId)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Food Detail")
    }
}
