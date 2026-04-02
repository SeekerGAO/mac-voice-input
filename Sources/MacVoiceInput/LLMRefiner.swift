import Foundation

struct LLMConfiguration {
    let baseURL: String
    let apiKey: String
    let model: String
}

struct ChatCompletionRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let temperature: Double
    let messages: [Message]
}

struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

enum LLMRefinerError: LocalizedError {
    case invalidBaseURL
    case insecureBaseURL
    case badStatus(Int)
    case emptyResponse
    case transcriptTooLong

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid API Base URL."
        case .insecureBaseURL:
            return "Only HTTPS API endpoints are allowed, except localhost for local development."
        case .badStatus(let statusCode):
            return "Server returned HTTP \(statusCode)."
        case .emptyResponse:
            return "Model response was empty."
        case .transcriptTooLong:
            return "Transcript is too long for refinement."
        }
    }
}

struct LLMRefiner {
    private let maxTranscriptLength = 4000

    func refine(text: String, configuration: LLMConfiguration) async throws -> String {
        guard text.count <= maxTranscriptLength else {
            throw LLMRefinerError.transcriptTooLong
        }
        let endpoint = try endpointURL(from: configuration.baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body = ChatCompletionRequest(
            model: configuration.model,
            temperature: 0.1,
            messages: [
                .init(
                    role: "system",
                    content: """
                    You refine streaming speech-recognition output.
                    Be extremely conservative.
                    Only fix obvious recognition mistakes, such as Chinese homophone errors or English technical terms that were converted into wrong Chinese words.
                    Never rewrite, polish, reorder, summarize, add punctuation beyond what is clearly implied, or remove any content that already looks correct.
                    If the input already looks correct, return it exactly as-is.
                    Return only the final corrected text.
                    """
                ),
                .init(role: "user", content: text)
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMRefinerError.emptyResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw LLMRefinerError.badStatus(httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw LLMRefinerError.emptyResponse
        }
        return content
    }

    func test(configuration: LLMConfiguration) async throws -> String {
        try await refine(text: "配森 和 杰森", configuration: configuration)
    }

    private func endpointURL(from baseURL: String) throws -> URL {
        guard var url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw LLMRefinerError.invalidBaseURL
        }
        if !isAllowedScheme(url) {
            throw LLMRefinerError.insecureBaseURL
        }
        if !url.path.hasSuffix("/chat/completions") {
            url.append(path: "chat")
            url.append(path: "completions")
        }
        return url
    }

    private func isAllowedScheme(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "https" {
            return true
        }
        if scheme == "http" {
            let host = url.host?.lowercased() ?? ""
            return host == "localhost" || host == "127.0.0.1"
        }
        return false
    }
}
