import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let selectedLanguage = "selectedLanguage"
        static let llmEnabled = "llmEnabled"
        static let apiBaseURL = "apiBaseURL"
        static let apiKey = "apiKey"
        static let model = "model"
    }

    @Published var selectedLanguage: LanguageOption {
        didSet { defaults.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage) }
    }

    @Published var llmEnabled: Bool {
        didSet { defaults.set(llmEnabled, forKey: Keys.llmEnabled) }
    }

    @Published var apiBaseURL: String {
        didSet { defaults.set(apiBaseURL, forKey: Keys.apiBaseURL) }
    }

    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: Keys.apiKey) }
    }

    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedLanguage = defaults.string(forKey: Keys.selectedLanguage).flatMap(LanguageOption.init(rawValue:))
        self.selectedLanguage = savedLanguage ?? .defaultOption
        self.llmEnabled = defaults.object(forKey: Keys.llmEnabled) as? Bool ?? false
        self.apiBaseURL = defaults.string(forKey: Keys.apiBaseURL) ?? ""
        self.apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        self.model = defaults.string(forKey: Keys.model) ?? ""
    }

    var llmConfiguration: LLMConfiguration? {
        let baseURL = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty, !key.isEmpty, !model.isEmpty else {
            return nil
        }
        return LLMConfiguration(baseURL: baseURL, apiKey: key, model: model)
    }
}
