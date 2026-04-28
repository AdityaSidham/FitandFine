import SwiftUI
import Combine

// MARK: - Navigation Destination

enum FoodLogDestination: Hashable {
    case addFood
    case foodSearch
    case foodDetail(foodId: String)
    case manualEntry
}

// MARK: - Food Log Coordinator

@MainActor
final class FoodLogCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    func navigate(to destination: FoodLogDestination) {
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

// MARK: - Food Log Coordinator View

struct FoodLogCoordinatorView: View {
    @ObservedObject var coordinator: FoodLogCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            FoodLogView(coordinator: coordinator)
                .navigationDestination(for: FoodLogDestination.self) { destination in
                    switch destination {
                    case .addFood:
                        AddFoodSelectionView(coordinator: coordinator)
                    case .foodSearch:
                        FoodLogSearchView(coordinator: coordinator)
                    case .foodDetail(let foodId):
                        FoodDetailView(foodId: foodId, onDismiss: { coordinator.popToRoot() })
                    case .manualEntry:
                        ManualFoodEntryView(coordinator: coordinator)
                    }
                }
        }
    }
}

// MARK: - Supporting Views

struct AddFoodSelectionView: View {
    let coordinator: FoodLogCoordinator

    var body: some View {
        List {
            Button {
                coordinator.navigate(to: .foodSearch)
            } label: {
                Label("Search Food Database", systemImage: "magnifyingglass")
            }

            Button {
                coordinator.navigate(to: .manualEntry)
            } label: {
                Label("Manual Entry", systemImage: "pencil")
            }
        }
        .navigationTitle("Add Food")
    }
}

struct FoodLogSearchView: View {
    let coordinator: FoodLogCoordinator
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

struct ManualFoodEntryView: View {
    let coordinator: FoodLogCoordinator
    @State private var foodName = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var selectedMeal = "breakfast"

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    var body: some View {
        Form {
            Section("Food Details") {
                TextField("Food Name", text: $foodName)
                TextField("Calories", text: $calories)
                    .keyboardType(.decimalPad)
            }

            Section("Macros (optional)") {
                TextField("Protein (g)", text: $protein)
                    .keyboardType(.decimalPad)
                TextField("Carbs (g)", text: $carbs)
                    .keyboardType(.decimalPad)
                TextField("Fat (g)", text: $fat)
                    .keyboardType(.decimalPad)
            }

            Section("Meal") {
                Picker("Meal Type", selection: $selectedMeal) {
                    ForEach(mealTypes, id: \.self) { meal in
                        Text(meal.capitalized).tag(meal)
                    }
                }
            }

            Section {
                Button("Add to Log") {
                    coordinator.popToRoot()
                }
                .foregroundStyle(.green)
                .disabled(foodName.isEmpty || calories.isEmpty)
            }
        }
        .navigationTitle("Manual Entry")
    }
}
