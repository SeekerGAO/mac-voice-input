import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(settings: SettingsStore, refiner: LLMRefiner) {
        let view = SettingsView(settings: settings, refiner: refiner)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "LLM Refinement Settings"
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
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

    init(settings: SettingsStore, refiner: LLMRefiner) {
        self.settings = settings
        self.refiner = refiner
        _draftBaseURL = State(initialValue: settings.apiBaseURL)
        _draftAPIKey = State(initialValue: settings.apiKey)
        _draftModel = State(initialValue: settings.model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("API Base URL")
                TextField("https://api.openai.com/v1", text: $draftBaseURL)
                    .textFieldStyle(.roundedBorder)

                Text("API Key")
                SecureField("sk-...", text: $draftAPIKey)
                    .textFieldStyle(.roundedBorder)

                Text("Model")
                TextField("gpt-4.1-mini", text: $draftModel)
                    .textFieldStyle(.roundedBorder)
            }

            if let keychainError = settings.lastKeychainError {
                Text("Keychain error: \(keychainError)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button(isTesting ? "Testing…" : "Test") {
                    testConnection()
                }
                .disabled(isTesting || draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Save") {
                    settings.apiBaseURL = draftBaseURL
                    settings.apiKey = draftAPIKey
                    settings.model = draftModel
                    testResult = settings.lastKeychainError == nil ? "Saved." : "Saved, but the API key was not written to Keychain."
                }

                Text(testResult)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func testConnection() {
        let config = LLMConfiguration(
            baseURL: draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: draftModel.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard !config.baseURL.isEmpty, !config.apiKey.isEmpty, !config.model.isEmpty else {
            testResult = "Fill all fields before testing."
            return
        }

        isTesting = true
        testResult = ""
        Task {
            defer { isTesting = false }
            do {
                let result = try await refiner.test(configuration: config)
                testResult = "Success: \(result)"
            } catch {
                testResult = error.localizedDescription
            }
        }
    }
}
