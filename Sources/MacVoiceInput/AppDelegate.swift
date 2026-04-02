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
    private var strings: AppStrings { AppStrings(language: settings.selectedLanguage) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureServices()
        configureNotifications()
        presentOnboardingIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor.stop()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform.badge.mic", accessibilityDescription: "Voice Input")
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = strings.holdFnTooltip
        floatingPanel.setLanguage(settings.selectedLanguage)
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
            showUserMessage(strings.permissionAccessHint)
        }
    }

    private func configureNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let bundlePathItem = NSMenuItem(title: "Path: \(Bundle.main.bundlePath)", action: nil, keyEquivalent: "")
        bundlePathItem.isEnabled = false
        menu.addItem(bundlePathItem)
        menu.addItem(.separator())

        let diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
        let diagnosticsItem = NSMenuItem(title: strings.permissionDiagnostics, action: nil, keyEquivalent: "")
        let diagnosticsMenu = NSMenu()
        diagnosticsMenu.addItem(makeSummaryStatusItem(diagnostics: diagnostics))
        diagnosticsMenu.addItem(.separator())
        diagnosticsMenu.addItem(makeStatusItem(title: localizedMicrophoneTitle(), state: diagnostics.microphone))
        diagnosticsMenu.addItem(makeStatusItem(title: localizedSpeechTitle(), state: diagnostics.speechRecognition))
        diagnosticsMenu.addItem(makeStatusItem(title: localizedAccessibilityTitle(), state: diagnostics.accessibility))
        diagnosticsMenu.addItem(makeStatusItem(title: localizedInputMonitoringTitle(), state: diagnostics.inputMonitoring))
        diagnosticsMenu.addItem(.separator())
        let openPrivacyItem = NSMenuItem(title: strings.openPrivacySettings, action: #selector(openPrivacySettings), keyEquivalent: "")
        openPrivacyItem.target = self
        diagnosticsMenu.addItem(openPrivacyItem)
        let requestPermissionsItem = NSMenuItem(title: strings.requestMediaPermissionsMenu, action: #selector(requestMediaPermissionsFromMenu), keyEquivalent: "")
        requestPermissionsItem.target = self
        diagnosticsMenu.addItem(requestPermissionsItem)
        let requestAccessibilityItem = NSMenuItem(title: strings.requestAccessibilityPermissionMenu, action: #selector(requestAccessibilityPermissionFromMenu), keyEquivalent: "")
        requestAccessibilityItem.target = self
        diagnosticsMenu.addItem(requestAccessibilityItem)
        let requestInputMonitoringItem = NSMenuItem(title: strings.requestInputMonitoringPermissionMenu, action: #selector(requestInputMonitoringPermissionFromMenu), keyEquivalent: "")
        requestInputMonitoringItem.target = self
        diagnosticsMenu.addItem(requestInputMonitoringItem)
        let rebuildItem = NSMenuItem(title: strings.rebuildMonitoring, action: #selector(rebuildMonitoring), keyEquivalent: "")
        rebuildItem.target = self
        diagnosticsMenu.addItem(rebuildItem)
        let refreshItem = NSMenuItem(title: strings.refreshPermissionState, action: #selector(refreshPermissionState), keyEquivalent: "")
        refreshItem.target = self
        diagnosticsMenu.addItem(refreshItem)
        let guideItem = NSMenuItem(title: strings.openFirstRunGuide, action: #selector(openOnboardingGuide), keyEquivalent: "")
        guideItem.target = self
        diagnosticsMenu.addItem(guideItem)
        diagnosticsItem.submenu = diagnosticsMenu
        menu.addItem(diagnosticsItem)
        menu.addItem(.separator())

        let languageMenuItem = NSMenuItem(title: strings.languageMenu, action: nil, keyEquivalent: "")
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

        let llmMenuItem = NSMenuItem(title: strings.llmRefinement, action: nil, keyEquivalent: "")
        let llmMenu = NSMenu()
        let enabledItem = NSMenuItem(title: strings.enableRefinement, action: #selector(toggleLLM(_:)), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = settings.llmEnabled ? .on : .off
        enabledItem.isEnabled = settings.llmConfiguration != nil
        llmMenu.addItem(enabledItem)

        let settingsItem = NSMenuItem(title: strings.settings, action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)
        llmMenuItem.submenu = llmMenu
        menu.addItem(llmMenuItem)

        if diagnostics.hasBlockingIssue {
            let guidanceItem = NSMenuItem(title: strings.permissionsRequired, action: nil, keyEquivalent: "")
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

        let quitItem = NSMenuItem(title: strings.quit, action: #selector(quit), keyEquivalent: "q")
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
        statusItem.button?.toolTip = strings.holdFnTooltip
        floatingPanel.setLanguage(language)
        rebuildMenu()
    }

    @objc
    private func toggleLLM(_ sender: NSMenuItem) {
        guard settings.llmConfiguration != nil else {
            showUserMessage(strings.configureAPISettingsFirst)
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
            onboardingWindowController = OnboardingWindowController(
                settings: settings,
                hotkeyMonitor: hotkeyMonitor,
                onRefreshPermissions: { [weak self] in
                    await self?.refreshPermissionDiagnostics() ?? PermissionDiagnosticsService.current(hotkeyMonitorAvailable: false)
                },
                onRequestMediaPermissions: { [weak self] in
                    await self?.requestMediaPermissionsAndRefresh() ?? PermissionDiagnosticsService.current(hotkeyMonitorAvailable: false)
                }
            )
        }
        settings.hasSeenOnboarding = true
        onboardingWindowController?.show()
    }

    @objc
    private func requestMediaPermissionsFromMenu() {
        Task { @MainActor in
            _ = await requestMediaPermissionsAndRefresh()
            showUserMessage(strings.permissionStateRefreshed)
        }
    }

    @objc
    private func requestAccessibilityPermissionFromMenu() {
        Task { @MainActor in
            _ = PermissionDiagnosticsService.requestAccessibilityPermission()
            _ = await refreshPermissionDiagnostics()
            showUserMessage(strings.permissionStateRefreshed)
        }
    }

    @objc
    private func requestInputMonitoringPermissionFromMenu() {
        Task { @MainActor in
            _ = PermissionDiagnosticsService.requestInputMonitoringPermission()
            _ = await refreshPermissionDiagnostics()
            showUserMessage(strings.permissionStateRefreshed)
        }
    }

    @objc
    private func rebuildMonitoring() {
        Task { @MainActor in
            hotkeyMonitor.refresh()
            rebuildMenu()
            showUserMessage(strings.monitoringRebuilt)
        }
    }

    @objc
    private func refreshPermissionState() {
        Task { @MainActor in
            _ = await refreshPermissionDiagnostics()
            showUserMessage(strings.permissionStateRefreshed)
        }
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    private func beginRecording() {
        guard case .idle = captureState else { return }
        Task {
            let diagnostics = await requestMediaPermissionsAndRefreshIfNeeded()
            guard !diagnostics.hasBlockingIssue else {
                showUserMessage(strings.completePermissionsFirst)
                if diagnostics.inputMonitoring == .inferredUnavailable {
                    showUserMessage(strings.restartMayBeRequired)
                }
                openOnboardingGuide()
                return
            }

            let sessionID = UUID()
            captureState = .starting(sessionID)
            pendingStopSessionID = nil
            lastUserMessage = nil
            floatingPanel.showListening()

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
                let message = strings.errorMessage(for: error)
                showUserMessage(message)
                floatingPanel.showMessage(message)
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
                        showUserMessage(strings.llmTimedOutFallback)
                    } else {
                        showUserMessage(strings.llmFailedFallback)
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

    @objc
    private func handleAppDidBecomeActive() {
        Task { @MainActor in
            _ = await refreshPermissionDiagnostics()
        }
    }

    private func requestMediaPermissionsAndRefreshIfNeeded() async -> PermissionDiagnostics {
        hotkeyMonitor.refresh()
        var diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
        if diagnostics.microphone == .notDetermined || diagnostics.speechRecognition == .notDetermined {
            NSApp.activate(ignoringOtherApps: true)
            await speechRecognizer.requestPermissions()
            try? await Task.sleep(for: .milliseconds(250))
            hotkeyMonitor.refresh()
            diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
            rebuildMenu()
        }
        return diagnostics
    }

    private func requestMediaPermissionsAndRefresh() async -> PermissionDiagnostics {
        NSApp.activate(ignoringOtherApps: true)
        await speechRecognizer.requestPermissions()
        try? await Task.sleep(for: .milliseconds(250))
        return await refreshPermissionDiagnostics()
    }

    private func refreshPermissionDiagnostics() async -> PermissionDiagnostics {
        hotkeyMonitor.refresh()
        let diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
        rebuildMenu()
        return diagnostics
    }

    private func makeStatusItem(title: String, state: PermissionState) -> NSMenuItem {
        let prefix = statusPrefix(for: state)
        let text = "\(prefix) \(title): \(state.title(for: settings.selectedLanguage))"
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ]
        )
        attributed.addAttributes(
            [.foregroundColor: statusColor(for: state)],
            range: NSRange(location: 0, length: (prefix as NSString).length)
        )

        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.attributedTitle = attributed
        item.toolTip = state.title(for: settings.selectedLanguage)
        item.isEnabled = false
        return item
    }

    private func makeSummaryStatusItem(diagnostics: PermissionDiagnostics) -> NSMenuItem {
        let hasIssues = diagnostics.hasBlockingIssue || diagnostics.microphone == .notDetermined || diagnostics.speechRecognition == .notDetermined
        let title = hasIssues ? strings.permissionIssuesFound : strings.permissionAllGood
        let icon = hasIssues ? "⚠" : "✓"
        let text = "\(icon) \(title)"
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ]
        )
        attributed.addAttributes(
            [.foregroundColor: hasIssues ? NSColor.systemOrange : NSColor.systemGreen],
            range: NSRange(location: 0, length: (icon as NSString).length)
        )

        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.attributedTitle = attributed
        item.isEnabled = false
        return item
    }

    private func statusPrefix(for state: PermissionState) -> String {
        switch state {
        case .granted:
            return "✓"
        case .notDetermined:
            return "◌"
        case .denied, .inferredUnavailable:
            return "⚠"
        }
    }

    private func statusColor(for state: PermissionState) -> NSColor {
        switch state {
        case .granted:
            return .systemGreen
        case .notDetermined:
            return .systemYellow
        case .denied, .inferredUnavailable:
            return .systemOrange
        }
    }

    private func localizedMicrophoneTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "Microphone"
        case .simplifiedChinese: return "麦克风"
        case .traditionalChinese: return "麥克風"
        case .japanese: return "マイク"
        case .korean: return "마이크"
        }
    }

    private func localizedSpeechTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "Speech Recognition"
        case .simplifiedChinese: return "语音识别"
        case .traditionalChinese: return "語音辨識"
        case .japanese: return "音声認識"
        case .korean: return "음성 인식"
        }
    }

    private func localizedAccessibilityTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "Accessibility"
        case .simplifiedChinese: return "辅助功能"
        case .traditionalChinese: return "輔助使用"
        case .japanese: return "アクセシビリティ"
        case .korean: return "손쉬운 사용"
        }
    }

    private func localizedInputMonitoringTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "Input Monitoring (Inferred)"
        case .simplifiedChinese: return "输入监控（推断）"
        case .traditionalChinese: return "輸入監控（推斷）"
        case .japanese: return "入力監視（推定）"
        case .korean: return "입력 모니터링(추정)"
        }
    }

}
