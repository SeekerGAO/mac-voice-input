import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settings: SettingsStore

    init(settings: SettingsStore, refiner: LLMRefiner) {
        self.settings = settings
        let view = SettingsView(settings: settings, refiner: refiner)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = Self.windowTitle(for: settings.selectedLanguage)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 300))
        window.center()
        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.title = Self.windowTitle(for: settings.selectedLanguage)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func windowTitle(for language: LanguageOption) -> String {
        switch language {
        case .english: return "LLM Refinement Settings"
        case .simplifiedChinese: return "LLM 优化设置"
        case .traditionalChinese: return "LLM 優化設定"
        case .japanese: return "LLM 補正設定"
        case .korean: return "LLM 보정 설정"
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let refiner: LLMRefiner

    @State private var draftBaseURL: String
    @State private var draftAPIKey: String
    @State private var draftModel: String
    @State private var testResult: String = ""
    @State private var isTesting = false
    @State private var showClearAPIKeyConfirmation = false

    init(settings: SettingsStore, refiner: LLMRefiner) {
        self.settings = settings
        self.refiner = refiner
        _draftBaseURL = State(initialValue: settings.apiBaseURL)
        _draftAPIKey = State(initialValue: settings.apiKey)
        _draftModel = State(initialValue: settings.model)
    }

    var body: some View {
        let strings = AppStrings(language: settings.selectedLanguage)
        VStack(alignment: .leading, spacing: 16) {
            keychainStatusBar(strings: strings)

            Group {
                Text(strings.apiBaseURLLabel)
                TextField(strings.apiBaseURLPlaceholder, text: $draftBaseURL)
                    .textFieldStyle(.roundedBorder)

                Text(strings.apiKeyLabel)
                SecureField(strings.apiKeyPlaceholder, text: $draftAPIKey)
                    .textFieldStyle(.roundedBorder)

                Text(strings.modelLabel)
                TextField(strings.modelPlaceholder, text: $draftModel)
                    .textFieldStyle(.roundedBorder)
            }

            if let keychainError = settings.lastKeychainError {
                Text("\(localizedKeychainLabel(for: settings.selectedLanguage)): \(keychainError)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button(isTesting ? localizedTesting(for: settings.selectedLanguage) : localizedTest(for: settings.selectedLanguage)) {
                    testConnection()
                }
                .disabled(isTesting || draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(localizedSave(for: settings.selectedLanguage)) {
                    settings.apiBaseURL = draftBaseURL
                    settings.apiKey = draftAPIKey
                    settings.model = draftModel
                    testResult = settings.lastKeychainError == nil ? localizedSaved(for: settings.selectedLanguage) : localizedSavedWithKeychainWarning(for: settings.selectedLanguage)
                }

                Button(strings.clearAPIKey) {
                    showClearAPIKeyConfirmation = true
                }
                .disabled(draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text(testResult)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            strings.confirmClearAPIKeyTitle,
            isPresented: $showClearAPIKeyConfirmation,
            titleVisibility: .visible
        ) {
            Button(strings.clearAction, role: .destructive) {
                draftAPIKey = ""
                settings.apiKey = ""
                testResult = localizedKeychainCleared(for: settings.selectedLanguage)
            }
            Button(strings.cancelAction, role: .cancel) {}
        } message: {
            Text(strings.confirmClearAPIKeyMessage)
        }
    }

    private func testConnection() {
        let config = LLMConfiguration(
            baseURL: draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: draftModel.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard !config.baseURL.isEmpty, !config.apiKey.isEmpty, !config.model.isEmpty else {
            testResult = localizedFillAllFields(for: settings.selectedLanguage)
            return
        }

        isTesting = true
        testResult = ""
        Task {
            defer { isTesting = false }
            do {
                let result = try await refiner.test(configuration: config)
                testResult = "\(localizedSuccess(for: settings.selectedLanguage)): \(result)"
            } catch {
                testResult = AppStrings(language: settings.selectedLanguage).errorMessage(for: error)
            }
        }
    }

    @ViewBuilder
    private func keychainStatusBar(strings: AppStrings) -> some View {
        switch settings.keychainStatus {
        case .idle:
            EmptyView()
        case .saved:
            Label(localizedKeychainSaved(for: settings.selectedLanguage), systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .failed:
            Label(localizedKeychainFailed(for: settings.selectedLanguage), systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func localizedKeychainLabel(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Keychain error"
        case .simplifiedChinese: return "钥匙串错误"
        case .traditionalChinese: return "鑰匙圈錯誤"
        case .japanese: return "キーチェーンエラー"
        case .korean: return "키체인 오류"
        }
    }

    private func localizedTesting(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Testing…"
        case .simplifiedChinese: return "测试中…"
        case .traditionalChinese: return "測試中…"
        case .japanese: return "テスト中…"
        case .korean: return "테스트 중…"
        }
    }

    private func localizedTest(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Test"
        case .simplifiedChinese: return "测试"
        case .traditionalChinese: return "測試"
        case .japanese: return "テスト"
        case .korean: return "테스트"
        }
    }

    private func localizedSave(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Save"
        case .simplifiedChinese: return "保存"
        case .traditionalChinese: return "儲存"
        case .japanese: return "保存"
        case .korean: return "저장"
        }
    }

    private func localizedSaved(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Saved."
        case .simplifiedChinese: return "已保存。"
        case .traditionalChinese: return "已儲存。"
        case .japanese: return "保存しました。"
        case .korean: return "저장되었습니다."
        }
    }

    private func localizedSavedWithKeychainWarning(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Saved, but the API key was not written to Keychain."
        case .simplifiedChinese: return "已保存，但 API Key 未写入钥匙串。"
        case .traditionalChinese: return "已儲存，但 API Key 未寫入鑰匙圈。"
        case .japanese: return "保存されましたが、API Key はキーチェーンに保存されませんでした。"
        case .korean: return "저장되었지만 API Key가 키체인에 저장되지 않았습니다."
        }
    }

    private func localizedFillAllFields(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Fill all fields before testing."
        case .simplifiedChinese: return "请先填写完整后再测试。"
        case .traditionalChinese: return "請先填寫完整後再測試。"
        case .japanese: return "先にすべて入力してからテストしてください。"
        case .korean: return "먼저 모든 필드를 입력한 뒤 테스트하세요."
        }
    }

    private func localizedSuccess(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Success"
        case .simplifiedChinese: return "成功"
        case .traditionalChinese: return "成功"
        case .japanese: return "成功"
        case .korean: return "성공"
        }
    }

    private func localizedKeychainSaved(for language: LanguageOption) -> String {
        switch language {
        case .english: return "API Key has been saved to Keychain."
        case .simplifiedChinese: return "API Key 已保存到钥匙串。"
        case .traditionalChinese: return "API Key 已儲存到鑰匙圈。"
        case .japanese: return "API Key はキーチェーンに保存されました。"
        case .korean: return "API Key가 키체인에 저장되었습니다."
        }
    }

    private func localizedKeychainFailed(for language: LanguageOption) -> String {
        switch language {
        case .english: return "API Key could not be saved to Keychain."
        case .simplifiedChinese: return "API Key 未能保存到钥匙串。"
        case .traditionalChinese: return "API Key 無法儲存到鑰匙圈。"
        case .japanese: return "API Key をキーチェーンに保存できませんでした。"
        case .korean: return "API Key를 키체인에 저장하지 못했습니다."
        }
    }

    private func localizedKeychainCleared(for language: LanguageOption) -> String {
        switch language {
        case .english: return "API Key cleared."
        case .simplifiedChinese: return "API Key 已清空。"
        case .traditionalChinese: return "API Key 已清空。"
        case .japanese: return "API Key を消去しました。"
        case .korean: return "API Key를 지웠습니다."
        }
    }
}
