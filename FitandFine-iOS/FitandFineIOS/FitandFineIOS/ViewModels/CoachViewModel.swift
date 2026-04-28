import Foundation
import Combine

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var text: String
    let timestamp: Date

    enum Role { case user, coach }
}

// MARK: - CoachViewModel

@MainActor
class CoachViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isStreaming: Bool = false
    @Published var isLoadingReport: Bool = false
    @Published var weeklyReport: WeeklyReportResponse? = nil
    @Published var errorMessage: String? = nil

    private var currentSessionId: String? = nil
    private var streamingTask: Task<Void, Never>? = nil

    // MARK: - Send message

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        inputText = ""

        // Append user bubble immediately
        messages.append(ChatMessage(role: .user, text: text, timestamp: Date()))

        // Append empty coach bubble that will be filled by stream
        let coachMsgId = UUID()
        messages.append(ChatMessage(role: .coach, text: "", timestamp: Date()))
        let coachIdx = messages.count - 1

        isStreaming = true

        await streamCoachReply(userMessage: text, coachIdx: coachIdx)

        isStreaming = false
    }

    // MARK: - Load weekly report

    func loadWeeklyReport() async {
        guard !isLoadingReport else { return }
        isLoadingReport = true
        defer { isLoadingReport = false }

        do {
            let report: WeeklyReportResponse = try await NetworkClient.shared.get("/ai/weekly-report")
            weeklyReport = report
        } catch NetworkError.serverError(let code, let msg) where code == 429 {
            errorMessage = "AI quota exhausted. Update GEMINI_API_KEY in backend .env."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearConversation() {
        messages = []
        currentSessionId = nil
        streamingTask?.cancel()
    }

    // MARK: - SSE streaming

    private func streamCoachReply(userMessage: String, coachIdx: Int) async {
        let baseURL = NetworkClient.shared.baseURLString
        guard let url = URL(string: "\(baseURL)/ai/coach/message") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        if let token = KeychainHelper.shared.read(service: "fitandfine", account: "access_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = CoachMessageRequest(message: userMessage, sessionId: currentSessionId)
        guard let encoded = try? JSONEncoder().encode(body) else { return }
        // snake_case encoding for backend
        let snakeEncoder = JSONEncoder()
        snakeEncoder.keyEncodingStrategy = .convertToSnakeCase
        guard let snakeBody = try? snakeEncoder.encode(body) else { return }
        request.httpBody = snakeBody

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                messages[coachIdx].text = "Error \(http.statusCode): AI service unavailable."
                return
            }

            var buffer = ""

            for try await byte in bytes {
                buffer.append(Character(UnicodeScalar(byte)))

                // SSE events are delimited by double newline
                if buffer.hasSuffix("\n\n") {
                    for line in buffer.components(separatedBy: "\n") {
                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))
                            if let data = jsonStr.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(CoachSSEChunk.self, from: data) {
                                if let err = chunk.error {
                                    messages[coachIdx].text = "Error: \(err)"
                                    return
                                }
                                if chunk.done == true { return }
                                if let text = chunk.text, !text.isEmpty {
                                    messages[coachIdx].text += text
                                }
                            }
                        }
                    }
                    buffer = ""
                }
            }
        } catch {
            if !Task.isCancelled {
                messages[coachIdx].text = "Connection error. Is the backend running?"
            }
        }
    }
}
