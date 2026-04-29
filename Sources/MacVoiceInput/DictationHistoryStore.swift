import AppKit
import Foundation

struct DictationHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let sourceLanguage: LanguageOption
    let outputMode: VoiceOutputMode
    let appName: String?
    let rawTranscript: String
    let finalText: String
}

@MainActor
final class DictationHistoryStore: ObservableObject {
    private enum Constants {
        static let storageKey = "dictationHistoryItems"
        static let maxItems = 50
        static let previewLength = 42
    }

    @Published private(set) var items: [DictationHistoryItem]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.loadItems(from: defaults)
    }

    func add(rawTranscript: String, finalText: String, options: VoiceProcessingOptions) {
        let trimmedFinalText = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFinalText.isEmpty else { return }
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let item = DictationHistoryItem(
            id: UUID(),
            createdAt: Date(),
            sourceLanguage: options.sourceLanguage,
            outputMode: options.outputMode,
            appName: frontmostApplication?.localizedName,
            rawTranscript: rawTranscript,
            finalText: trimmedFinalText
        )
        items.insert(item, at: 0)
        if items.count > Constants.maxItems {
            items.removeLast(items.count - Constants.maxItems)
        }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func item(with id: UUID) -> DictationHistoryItem? {
        items.first { $0.id == id }
    }

    func preview(for item: DictationHistoryItem) -> String {
        let text = item.finalText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > Constants.previewLength else { return text }
        let endIndex = text.index(text.startIndex, offsetBy: Constants.previewLength)
        return "\(text[..<endIndex])..."
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Constants.storageKey)
        }
    }

    private static func loadItems(from defaults: UserDefaults) -> [DictationHistoryItem] {
        guard let data = defaults.data(forKey: Constants.storageKey),
              let decoded = try? JSONDecoder().decode([DictationHistoryItem].self, from: data) else {
            return []
        }
        return Array(decoded.prefix(Constants.maxItems))
    }
}
