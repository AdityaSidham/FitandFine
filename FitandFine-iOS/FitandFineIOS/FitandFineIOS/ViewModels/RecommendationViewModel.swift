import Foundation
import Combine

@MainActor
class RecommendationViewModel: ObservableObject {
    @Published var recommendations: RecommendationsResponse? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            recommendations = try await NetworkClient.shared.get("/ai/recommendations")
        } catch NetworkError.serverError(let code, _) where code == 429 {
            errorMessage = "AI quota exhausted — update GEMINI_API_KEY in .env"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async { await load() }
}
