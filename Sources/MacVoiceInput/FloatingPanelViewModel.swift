import AppKit
import Foundation

@MainActor
final class FloatingPanelViewModel: ObservableObject {
    enum Status {
        case listening
        case refining
        case message(String)
    }

    @Published var transcript: String = ""
    @Published var barLevels: [CGFloat] = Array(repeating: 0.2, count: 5)
    @Published var status: Status = .listening
    @Published var language: LanguageOption = .defaultOption

    private var cachedWidth: CGFloat = 260
    private var widthCacheKey: String = ""

    var displayText: String {
        let strings = AppStrings(language: language)
        switch status {
        case .listening:
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? strings.listeningPlaceholder : trimmed
        case .refining:
            return strings.refiningText
        case .message(let text):
            return text
        }
    }

    var titleText: String {
        let strings = AppStrings(language: language)
        switch status {
        case .listening:
            return strings.listeningPlaceholder
        case .refining:
            return strings.refiningText
        case .message:
            return "MacVoiceInput"
        }
    }

    var secondaryText: String {
        switch status {
        case .listening:
            let trimmedTranscript = trimmedTranscript
            return trimmedTranscript.isEmpty ? "Hold Fn and speak clearly" : trimmedTranscript
        case .refining:
            return trimmedTranscript
        case .message(let text):
            return text
        }
    }

    var statusLabel: String {
        switch status {
        case .listening:
            return "REC"
        case .refining:
            return "AI"
        case .message:
            return "INFO"
        }
    }

    var panelWidth: CGFloat {
        let cacheKey = "\(language.rawValue)|\(titleText)|\(secondaryText)"
        if cacheKey != widthCacheKey {
            widthCacheKey = cacheKey
            cachedWidth = estimateWidth(forTitle: titleText, detail: secondaryText)
        }
        return cachedWidth
    }

    private var trimmedTranscript: String {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func estimateWidth(forTitle title: String, detail: String) -> CGFloat {
        let titleFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let detailFont = NSFont.systemFont(ofSize: 16, weight: .medium)
        let titleWidth = (title as NSString).size(withAttributes: [.font: titleFont]).width
        let detailWidth = (detail as NSString).size(withAttributes: [.font: detailFont]).width
        let width = max(titleWidth, detailWidth)
        return min(max(width + 160, 240), 620)
    }
}
