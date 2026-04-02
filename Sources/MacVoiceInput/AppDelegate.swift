import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum CaptureState {
        case idle
        case starting(UUID)
        case recording(UUID)
        case processing(UUID)
    }

    private enum RefinementError: LocalizedError {
        case timeout

        var errorDescription: String? {
            switch self {
            case .timeout:
                return "LLM refinement timed out."
            }
        }
    }

    private let settings = SettingsStore()
    private let floatingPanel = FloatingPanelController()
    private let speechRecognizer = SpeechRecognizerService()
    private let hotkeyMonitor = HotkeyMonitor()
    private let textInjector = TextInjector()
    private let llmRefiner = LLMRefiner()

    private var statusItem: NSStatusItem!
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var captureState: CaptureState = .idle
    private var pendingStopSessionID: UUID?
    private var lastUserMessage: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureServices()
        presentOnboardingIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor.stop()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform.badge.mic", accessibilityDescription: "Voice Input")
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "Hold Fn to record voice input"
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
        if !hotkeyMonitor.isMonitoringAvailable {
            showUserMessage("Grant Accessibility and Input Monitoring")
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
        let diagnosticsItem = NSMenuItem(title: "Permission Diagnostics", action: nil, keyEquivalent: "")
        let diagnosticsMenu = NSMenu()
        diagnosticsMenu.addItem(makeStatusItem(title: "Microphone", state: diagnostics.microphone))
        diagnosticsMenu.addItem(makeStatusItem(title: "Speech Recognition", state: diagnostics.speechRecognition))
        diagnosticsMenu.addItem(makeStatusItem(title: "Accessibility", state: diagnostics.accessibility))
        diagnosticsMenu.addItem(makeStatusItem(title: "Input Monitoring (Inferred)", state: diagnostics.inputMonitoring))
        diagnosticsMenu.addItem(.separator())
        let openPrivacyItem = NSMenuItem(title: "Open Privacy Settings", action: #selector(openPrivacySettings), keyEquivalent: "")
        openPrivacyItem.target = self
        diagnosticsMenu.addItem(openPrivacyItem)
        let guideItem = NSMenuItem(title: "Open First-Run Guide", action: #selector(openOnboardingGuide), keyEquivalent: "")
        guideItem.target = self
        diagnosticsMenu.addItem(guideItem)
        diagnosticsItem.submenu = diagnosticsMenu
        menu.addItem(diagnosticsItem)
        menu.addItem(.separator())

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
        enabledItem.isEnabled = settings.llmConfiguration != nil
        llmMenu.addItem(enabledItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)
        llmMenuItem.submenu = llmMenu
        menu.addItem(llmMenuItem)

        if diagnostics.hasBlockingIssue {
            let guidanceItem = NSMenuItem(title: "Permissions required before recording works", action: nil, keyEquivalent: "")
            guidanceItem.isEnabled = false
            menu.addItem(guidanceItem)
            menu.addItem(.separator())
        }

        if let lastUserMessage {
            let infoItem = NSMenuItem(title: lastUserMessage, action: nil, keyEquivalent: "")
            infoItem.isEnabled = false
            menu.addItem(infoItem)
            menu.addItem(.separator())
        }

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
        guard settings.llmConfiguration != nil else {
            showUserMessage("Configure API settings first")
            rebuildMenu()
            return
        }
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
    private func openPrivacySettings() {
        PermissionDiagnosticsService.openPrivacySettings()
    }

    @objc
    private func openOnboardingGuide() {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController(settings: settings, hotkeyMonitor: hotkeyMonitor)
        }
        settings.hasSeenOnboarding = true
        onboardingWindowController?.show()
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    private func beginRecording() {
        guard case .idle = captureState else { return }
        let diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
        guard !diagnostics.hasBlockingIssue else {
            showUserMessage("请先完成权限授权")
            openOnboardingGuide()
            return
        }
        let sessionID = UUID()
        captureState = .starting(sessionID)
        pendingStopSessionID = nil
        lastUserMessage = nil
        floatingPanel.showListening()
        Task {
            do {
                try await speechRecognizer.start(language: settings.selectedLanguage)
                guard case .starting(let activeSessionID) = captureState, activeSessionID == sessionID else {
                    _ = await speechRecognizer.stop()
                    return
                }
                captureState = .recording(sessionID)
                if pendingStopSessionID == sessionID {
                    pendingStopSessionID = nil
                    await stopRecording(sessionID: sessionID)
                }
            } catch {
                guard case .starting(let activeSessionID) = captureState, activeSessionID == sessionID else {
                    return
                }
                captureState = .idle
                showUserMessage(error.localizedDescription)
                floatingPanel.showMessage(error.localizedDescription)
                try? await Task.sleep(for: .seconds(1))
                floatingPanel.hide()
            }
        }
    }

    private func finishRecording() {
        switch captureState {
        case .idle, .processing:
            return
        case .starting(let sessionID):
            pendingStopSessionID = sessionID
        case .recording(let sessionID):
            Task { @MainActor in
                await stopRecording(sessionID: sessionID)
            }
        }
    }

    private func stopRecording(sessionID: UUID) async {
        guard case .recording(let activeSessionID) = captureState, activeSessionID == sessionID else { return }
        captureState = .processing(sessionID)
        Task {
            let transcript = await speechRecognizer.stop()
            defer {
                if case .processing(let activeSessionID) = captureState, activeSessionID == sessionID {
                    captureState = .idle
                }
            }

            guard !transcript.isEmpty else {
                floatingPanel.hide()
                return
            }

            var finalText = transcript
            if settings.llmEnabled, let configuration = settings.llmConfiguration {
                floatingPanel.showRefining(with: transcript)
                do {
                    finalText = try await refineWithTimeout(text: transcript, configuration: configuration)
                } catch {
                    if let refinementError = error as? RefinementError, refinementError == .timeout {
                        showUserMessage("LLM refinement timed out, using raw transcript")
                    } else {
                        showUserMessage("LLM refinement failed, using raw transcript")
                    }
                    finalText = transcript
                }
            }

            await textInjector.inject(finalText)
            floatingPanel.hide()
        }
    }

    private func refineWithTimeout(text: String, configuration: LLMConfiguration) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.llmRefiner.refine(text: text, configuration: configuration)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(8))
                throw RefinementError.timeout
            }

            guard let result = try await group.next() else {
                throw RefinementError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    private func showUserMessage(_ message: String) {
        lastUserMessage = message
        rebuildMenu()
    }

    private func presentOnboardingIfNeeded() {
        let diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
        guard diagnostics.hasBlockingIssue || !settings.hasSeenOnboarding else { return }
        openOnboardingGuide()
    }

    private func makeStatusItem(title: String, state: PermissionState) -> NSMenuItem {
        let item = NSMenuItem(title: "\(title): \(state.title)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
