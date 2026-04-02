import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let selectedLanguage = "selectedLanguage"
        static let llmEnabled = "llmEnabled"
        static let apiBaseURL = "apiBaseURL"
        static let model = "model"
        static let hasSeenOnboarding = "hasSeenOnboarding"
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
        didSet {
            do {
                try keychainStore.saveAPIKey(apiKey)
                lastKeychainError = nil
            } catch {
                lastKeychainError = error.localizedDescription
            }
        }
    }

    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    @Published var hasSeenOnboarding: Bool {
        didSet { defaults.set(hasSeenOnboarding, forKey: Keys.hasSeenOnboarding) }
    }

    private let defaults: UserDefaults
    private let keychainStore: KeychainStore
    @Published private(set) var lastKeychainError: String?

    init(defaults: UserDefaults = .standard, keychainStore: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychainStore = keychainStore
        let savedLanguage = defaults.string(forKey: Keys.selectedLanguage).flatMap(LanguageOption.init(rawValue:))
        self.selectedLanguage = savedLanguage ?? .defaultOption
        self.llmEnabled = defaults.object(forKey: Keys.llmEnabled) as? Bool ?? false
        self.apiBaseURL = defaults.string(forKey: Keys.apiBaseURL) ?? ""
        self.model = defaults.string(forKey: Keys.model) ?? ""
        self.hasSeenOnboarding = defaults.object(forKey: Keys.hasSeenOnboarding) as? Bool ?? false
        self.apiKey = ""

        do {
            self.apiKey = try keychainStore.readAPIKey()
        } catch {
            self.lastKeychainError = error.localizedDescription
        }
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
