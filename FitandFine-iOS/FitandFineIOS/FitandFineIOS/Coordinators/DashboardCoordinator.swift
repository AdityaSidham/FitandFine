import SwiftUI
import Combine

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
                        FoodDetailView(foodId: foodId, onDismiss: { coordinator.popToRoot() })
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
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Always-visible search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search foods…", text: $query)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onChange(of: query) { _, newValue in
                        Task { await viewModel.searchFoods(query: newValue) }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                        viewModel.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray5).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider()

            // Results
            if viewModel.isSearching {
                Spacer()
                ProgressView()
                Spacer()
            } else if query.count >= 2 && viewModel.searchResults.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(.systemGray3))
                    Text("No results for \"\(query)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if query.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(DS.Color.accent.opacity(0.5))
                    Text("Type to search the food database")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.searchResults) { food in
                        Button {
                            coordinator.navigate(to: .foodDetail(foodId: food.id))
                        } label: {
                            FoodSearchRow(food: food)
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Search Foods")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
    }
}

// FoodDetailView is in Views/Food/FoodDetailView.swift — shared by both coordinators.

// MARK: - Shared food search row (used by both Dashboard & FoodLog search views)

struct FoodSearchRow: View {
    let food: FoodItemResponse

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DS.Color.accent.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: "leaf.fill")
                    .font(.caption)
                    .foregroundStyle(DS.Color.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let brand = food.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if let serving = food.servingSizeDescription {
                        Text(serving)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let cal = food.calories {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Int(cal))")
                        .font(.subheadline.bold())
                        .foregroundStyle(DS.Color.accent)
                    Text("kcal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
