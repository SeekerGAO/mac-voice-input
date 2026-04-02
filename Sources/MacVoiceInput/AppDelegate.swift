import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let floatingPanel = FloatingPanelController()
    private let speechRecognizer = SpeechRecognizerService()
    private let hotkeyMonitor = HotkeyMonitor()
    private let textInjector = TextInjector()
    private let llmRefiner = LLMRefiner()

    private var statusItem: NSStatusItem!
    private var settingsWindowController: SettingsWindowController?
    private var isRecording = false
    private var isProcessing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureServices()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor.stop()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform.badge.mic", accessibilityDescription: "Voice Input")
        statusItem.button?.imagePosition = .imageOnly
        rebuildMenu()
    }

    private func configureServices() {
        speechRecognizer.onTranscript = { [weak self] transcript in
            self?.floatingPanel.updateTranscript(transcript)
        }
        speechRecognizer.onMeter = { [weak self] levels in
            self?.floatingPanel.updateMeter(levels: levels)
        }

        hotkeyMonitor.onFnPressed = { [weak self] in
            Task { @MainActor [weak self] in
                self?.beginRecording()
            }
        }
        hotkeyMonitor.onFnReleased = { [weak self] in
            Task { @MainActor [weak self] in
                self?.finishRecording()
            }
        }
        hotkeyMonitor.start()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let languageMenuItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for language in LanguageOption.allCases {
            let item = NSMenuItem(title: language.title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = language == settings.selectedLanguage ? .on : .off
            languageMenu.addItem(item)
        }
        languageMenuItem.submenu = languageMenu
        menu.addItem(languageMenuItem)

        let llmMenuItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        let llmMenu = NSMenu()
        let enabledItem = NSMenuItem(title: "Enable Refinement", action: #selector(toggleLLM(_:)), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = settings.llmEnabled ? .on : .off
        llmMenu.addItem(enabledItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)
        llmMenuItem.submenu = llmMenu
        menu.addItem(llmMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc
    private func selectLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = LanguageOption(rawValue: rawValue) else {
            return
        }
        settings.selectedLanguage = language
        rebuildMenu()
    }

    @objc
    private func toggleLLM(_ sender: NSMenuItem) {
        settings.llmEnabled.toggle()
        rebuildMenu()
    }

    @objc
    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings, refiner: llmRefiner)
        }
        settingsWindowController?.show()
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    private func beginRecording() {
        guard !isRecording, !isProcessing else { return }
        isRecording = true
        floatingPanel.showListening()
        Task {
            do {
                try await speechRecognizer.start(language: settings.selectedLanguage)
            } catch {
                isRecording = false
                floatingPanel.showMessage(error.localizedDescription)
                try? await Task.sleep(for: .seconds(1))
                floatingPanel.hide()
            }
        }
    }

    private func finishRecording() {
        guard isRecording, !isProcessing else { return }
        isRecording = false
        isProcessing = true

        Task {
            let transcript = await speechRecognizer.stop()
            defer {
                isProcessing = false
            }

            guard !transcript.isEmpty else {
                floatingPanel.hide()
                return
            }

            var finalText = transcript
            if settings.llmEnabled, let configuration = settings.llmConfiguration {
                floatingPanel.showRefining(with: transcript)
                do {
                    finalText = try await llmRefiner.refine(text: transcript, configuration: configuration)
                } catch {
                    finalText = transcript
                }
            }

            await textInjector.inject(finalText)
            floatingPanel.hide()
        }
    }
}
