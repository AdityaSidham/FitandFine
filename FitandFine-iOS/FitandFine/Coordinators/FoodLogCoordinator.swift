import SwiftUI

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
                        FoodLogDetailView(foodId: foodId, coordinator: coordinator)
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
                        HStack {
                            if let cal = food.calories {
                                Text("\(Int(cal)) kcal")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            if let serving = food.servingSizeDescription {
                                Text(serving)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .foregroundStyle(.primary)
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .navigationTitle("Search Foods")
        .searchable(text: $query, prompt: "Search foods...")
        .onChange(of: query) { _, newValue in
            Task { await viewModel.searchFoods(query: newValue) }
        }
    }
}

struct FoodLogDetailView: View {
    let foodId: String
    let coordinator: FoodLogCoordinator
    @StateObject private var logViewModel = FoodLogViewModel()
    @State private var quantity: Double = 1.0
    @State private var selectedMeal = "breakfast"
    @State private var isAdding = false

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Food ID: \(foodId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Meal Type")
                        .font(.headline)

                    Picker("Meal Type", selection: $selectedMeal) {
                        ForEach(mealTypes, id: \.self) { meal in
                            Text(meal.capitalized).tag(meal)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Quantity")
                        .font(.headline)

                    HStack {
                        Button {
                            if quantity > 0.5 { quantity -= 0.5 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }

                        Text(String(format: "%.1f", quantity))
                            .font(.title2.bold())
                            .frame(minWidth: 60)
                            .multilineTextAlignment(.center)

                        Button {
                            quantity += 0.5
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    isAdding = true
                    Task {
                        await logViewModel.addFoodLog(
                            foodItemId: foodId,
                            mealType: selectedMeal,
                            quantity: quantity
                        )
                        isAdding = false
                        coordinator.popToRoot()
                    }
                } label: {
                    HStack {
                        if isAdding {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Add to Log")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isAdding)
            }
            .padding()
        }
        .navigationTitle("Add Food")
    }
}

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
