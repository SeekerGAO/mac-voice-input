import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    enum KeychainStatus {
        case idle
        case saved
        case failed
    }

    private enum Keys {
        static let selectedLanguage = "selectedLanguage"
        static let llmEnabled = "llmEnabled"
        static let apiBaseURL = "apiBaseURL"
        static let model = "model"
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let outputMode = "outputMode"
        static let translationTargetLanguage = "translationTargetLanguage"
        static let personalDictionary = "personalDictionary"
        static let recordingMode = "recordingMode"
        static let activationHotkey = "activationHotkey"
        static let appStyleHintsEnabled = "appStyleHintsEnabled"
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
                keychainStatus = apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .idle : .saved
            } catch {
                lastKeychainError = AppStrings(language: selectedLanguage).errorMessage(for: error)
                keychainStatus = .failed
            }
        }
    }

    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    @Published var hasSeenOnboarding: Bool {
        didSet { defaults.set(hasSeenOnboarding, forKey: Keys.hasSeenOnboarding) }
    }

    @Published var outputMode: VoiceOutputMode {
        didSet { defaults.set(outputMode.rawValue, forKey: Keys.outputMode) }
    }

    @Published var translationTargetLanguage: LanguageOption {
        didSet { defaults.set(translationTargetLanguage.rawValue, forKey: Keys.translationTargetLanguage) }
    }

    @Published var personalDictionary: String {
        didSet { defaults.set(personalDictionary, forKey: Keys.personalDictionary) }
    }

    @Published var recordingMode: RecordingMode {
        didSet { defaults.set(recordingMode.rawValue, forKey: Keys.recordingMode) }
    }

    @Published var activationHotkey: ActivationHotkey {
        didSet { defaults.set(activationHotkey.rawValue, forKey: Keys.activationHotkey) }
    }

    @Published var appStyleHintsEnabled: Bool {
        didSet { defaults.set(appStyleHintsEnabled, forKey: Keys.appStyleHintsEnabled) }
    }

    private let defaults: UserDefaults
    private let keychainStore: KeychainStore
    @Published private(set) var lastKeychainError: String?
    @Published private(set) var keychainStatus: KeychainStatus = .idle

    init(defaults: UserDefaults = .standard, keychainStore: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychainStore = keychainStore
        let savedLanguage = defaults.string(forKey: Keys.selectedLanguage).flatMap(LanguageOption.init(rawValue:))
        self.selectedLanguage = savedLanguage ?? .defaultOption
        self.llmEnabled = defaults.object(forKey: Keys.llmEnabled) as? Bool ?? false
        self.apiBaseURL = defaults.string(forKey: Keys.apiBaseURL) ?? ""
        self.model = defaults.string(forKey: Keys.model) ?? ""
        self.hasSeenOnboarding = defaults.object(forKey: Keys.hasSeenOnboarding) as? Bool ?? false
        self.outputMode = defaults.string(forKey: Keys.outputMode).flatMap(VoiceOutputMode.init(rawValue:)) ?? .conservativeCorrection
        self.translationTargetLanguage = defaults.string(forKey: Keys.translationTargetLanguage).flatMap(LanguageOption.init(rawValue:)) ?? .english
        self.personalDictionary = defaults.string(forKey: Keys.personalDictionary) ?? ""
        self.recordingMode = defaults.string(forKey: Keys.recordingMode).flatMap(RecordingMode.init(rawValue:)) ?? .holdToRecord
        self.activationHotkey = defaults.string(forKey: Keys.activationHotkey).flatMap(ActivationHotkey.init(rawValue:)) ?? .fn
        self.appStyleHintsEnabled = defaults.object(forKey: Keys.appStyleHintsEnabled) as? Bool ?? true
        self.apiKey = ""

        do {
            self.apiKey = try keychainStore.readAPIKey()
            self.keychainStatus = self.apiKey.isEmpty ? .idle : .saved
        } catch {
            self.lastKeychainError = AppStrings(language: self.selectedLanguage).errorMessage(for: error)
            self.keychainStatus = .failed
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

    var personalDictionaryTerms: [String] {
        personalDictionary
            .components(separatedBy: CharacterSet(charactersIn: "\n,，、;；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var voiceProcessingOptions: VoiceProcessingOptions {
        VoiceProcessingOptions(
            outputMode: outputMode,
            sourceLanguage: selectedLanguage,
            translationTarget: translationTargetLanguage,
            personalDictionaryTerms: personalDictionaryTerms,
            selectedText: nil,
            appContext: appStyleHintsEnabled ? AppContext.current : nil
        )
    }
}
