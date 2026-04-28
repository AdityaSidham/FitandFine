import Foundation

// MARK: - NetworkError
enum NetworkError: LocalizedError {
    case invalidURL
    case unauthorized
    case notFound
    case conflict(String)
    case serverError(Int, String)
    case decodingError(Error)
    case noNetwork

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .unauthorized:
            return "You are not authorized. Please sign in again."
        case .notFound:
            return "The requested resource was not found."
        case .conflict(let message):
            return "Conflict: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noNetwork:
            return "No network connection. Please check your internet connection."
        }
    }
}

// MARK: - NetworkClient
actor NetworkClient {
    static let shared = NetworkClient()

    private let baseURL: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init(baseURL: String = "http://localhost:8000/api/v1") {
        self.baseURL = baseURL

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = enc
    }

    // MARK: - Public Methods

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await request(method: "GET", path: path, body: Optional<EmptyBody>.none)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "POST", path: path, body: body)
    }

    func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await request(method: "PUT", path: path, body: body)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await request(method: "DELETE", path: path, body: Optional<EmptyBody>.none)
    }

    // MARK: - Private Request Builder

    private func request<B: Encodable, T: Decodable>(
        method: String,
        path: String,
        body: B?
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        // Attach auth token if available
        if let token = KeychainHelper.shared.read(service: "fitandfine", account: "access_token") {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Encode body if present
        if let body {
            do {
                urlRequest.httpBody = try encoder.encode(body)
            } catch {
                throw NetworkError.decodingError(error)
            }
        }

        // Execute request
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch let urlError as URLError {
            throw NetworkError.noNetwork
        } catch {
            throw NetworkError.noNetwork
        }

        // Handle HTTP status codes
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            switch statusCode {
            case 200...299:
                break // success — fall through to decode
            case 401:
                throw NetworkError.unauthorized
            case 404:
                throw NetworkError.notFound
            case 409:
                let message = extractMessage(from: data) ?? "Conflict occurred."
                throw NetworkError.conflict(message)
            default:
                let message = extractMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
                throw NetworkError.serverError(statusCode, message)
            }
        }

        // Decode response
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    // MARK: - Helpers

    private func extractMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json["message"] as? String ?? json["detail"] as? String
        }
        return nil
    }
}

// MARK: - EmptyBody sentinel

private struct EmptyBody: Encodable {}
