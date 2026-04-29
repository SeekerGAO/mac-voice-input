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
    case unsupportedBaseURLComponents
    case badStatus(Int)
    case emptyResponse
    case transcriptTooLong

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid API Base URL."
        case .insecureBaseURL:
            return "Only HTTPS API endpoints are allowed, except localhost for local development."
        case .unsupportedBaseURLComponents:
            return "API Base URL must not include embedded credentials, query parameters, or fragments."
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
    private let session: URLSession

    init(session: URLSession = Self.makeSession()) {
        self.session = session
    }

    func refine(text: String, configuration: LLMConfiguration, options: VoiceProcessingOptions) async throws -> String {
        guard text.count <= maxTranscriptLength else {
            throw LLMRefinerError.transcriptTooLong
        }
        let endpoint = try endpointURL(from: configuration.baseURL)
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
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
                    content: systemPrompt(options: options)
                ),
                .init(role: "user", content: userPrompt(text: text, options: options))
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
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
        let options = VoiceProcessingOptions(
            outputMode: .conservativeCorrection,
            sourceLanguage: .simplifiedChinese,
            translationTarget: .english,
            personalDictionaryTerms: ["Python", "JSON"],
            selectedText: nil
        )
        return try await refine(text: "配森 和 杰森", configuration: configuration, options: options)
    }

    private func systemPrompt(options: VoiceProcessingOptions) -> String {
        let base = """
        You convert streaming speech-recognition output into text the user can paste immediately.
        Preserve the user's intent and factual content.
        Do not add explanations, markdown fences, labels, alternatives, or commentary.
        Return only the final text.
        Source language: \(options.sourceLanguage.title).
        """
        let dictionaryPrompt = personalDictionaryPrompt(terms: options.personalDictionaryTerms)

        switch options.outputMode {
        case .rawTranscript:
            return """
            \(base)
            Return the input exactly as-is.
            \(dictionaryPrompt)
            """
        case .conservativeCorrection:
            return """
            \(base)
            Be extremely conservative.
            Only fix obvious speech recognition mistakes, repeated filler words, mistaken homophones, capitalization, and punctuation that is clearly implied.
            Do not rewrite, polish, reorder, summarize, or remove content that already looks correct.
            If the input already looks correct, return it exactly as-is.
            \(dictionaryPrompt)
            """
        case .polishedMessage:
            return """
            \(base)
            Rewrite the transcript into a natural message suitable for chat or comments.
            Remove filler words, false starts, and accidental repetition.
            Keep the tone close to the speaker's tone.
            Keep it concise, but do not omit concrete details.
            \(dictionaryPrompt)
            """
        case .email:
            return """
            \(base)
            Rewrite the transcript as a clear, professional email or work message.
            Add a concise greeting or closing only when the transcript clearly implies one.
            Preserve names, dates, numbers, requirements, and commitments.
            \(dictionaryPrompt)
            """
        case .bulletList:
            return """
            \(base)
            Convert the transcript into a clean bullet list or numbered steps.
            Use bullets for unordered points and numbers for an ordered procedure.
            Keep each item short and concrete.
            \(dictionaryPrompt)
            """
        case .translation:
            return """
            \(base)
            Translate the transcript into \(options.translationTarget.title).
            Produce fluent, natural text in the target language.
            Preserve names, product terms, technical terms, dates, numbers, URLs, and code identifiers.
            \(dictionaryPrompt)
            """
        case .editSelectedText:
            return """
            \(base)
            The user selected existing text and then dictated an edit instruction.
            Apply the dictated instruction to the selected text.
            Return only the replacement text for the selection.
            Preserve the selected text's language unless the instruction asks for translation.
            Preserve names, dates, numbers, URLs, code identifiers, and technical terms.
            If the instruction is ambiguous, make the smallest useful edit.
            \(dictionaryPrompt)
            """
        }
    }

    private func userPrompt(text: String, options: VoiceProcessingOptions) -> String {
        guard options.outputMode == .editSelectedText else { return text }
        let selectedText = options.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return """
        Selected text:
        \(selectedText)

        Dictated edit instruction:
        \(text)
        """
    }

    private func personalDictionaryPrompt(terms: [String]) -> String {
        guard !terms.isEmpty else { return "" }
        let limitedTerms = terms.prefix(80).joined(separator: ", ")
        return "Personal dictionary terms to preserve or prefer when correcting recognition: \(limitedTerms)."
    }

    private func endpointURL(from baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased() else {
            throw LLMRefinerError.invalidBaseURL
        }
        if !isAllowedScheme(scheme: scheme, host: host) {
            throw LLMRefinerError.insecureBaseURL
        }
        let hasForbiddenComponents =
            components.user != nil ||
            components.password != nil ||
            components.query != nil ||
            components.fragment != nil
        guard !hasForbiddenComponents else {
            throw LLMRefinerError.unsupportedBaseURLComponents
        }
        var path = components.path
        if !path.hasSuffix("/chat/completions") {
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = path.isEmpty ? "/chat/completions" : "/\(path)/chat/completions"
        }
        guard let url = components.url else {
            throw LLMRefinerError.invalidBaseURL
        }
        return url
    }

    private func isAllowedScheme(scheme: String, host: String) -> Bool {
        if scheme == "https" {
            return true
        }
        if scheme == "http" {
            return host == "localhost" || host == "127.0.0.1"
        }
        return false
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}
