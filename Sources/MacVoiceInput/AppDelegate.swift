import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum MenuRefresh {
        static let debounceNanoseconds: UInt64 = 120_000_000
    }

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
    private let historyStore = DictationHistoryStore()

    private var statusItem: NSStatusItem!
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var captureState: CaptureState = .idle
    private var pendingStopSessionID: UUID?
    private var lastUserMessage: String?
    private var lastRenderedMenuState: MenuState?
    private var rebuildMenuTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var strings: AppStrings { AppStrings(language: settings.selectedLanguage) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureServices()
        configureSettingsObservers()
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
        statusItem.button?.toolTip = holdTooltip
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

        hotkeyMonitor.onActivationPressed = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleActivationPressed()
            }
        }
        hotkeyMonitor.onActivationReleased = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleActivationReleased()
            }
        }
        hotkeyMonitor.start(activationHotkey: settings.activationHotkey)
        if !hotkeyMonitor.isMonitoringAvailable {
            showUserMessage(strings.permissionAccessHint)
        }
    }

    private func configureSettingsObservers() {
        settings.$activationHotkey
            .dropFirst()
            .sink { [weak self] hotkey in
                guard let self else { return }
                self.hotkeyMonitor.refresh(activationHotkey: hotkey)
                self.statusItem.button?.toolTip = self.holdTooltip
                self.invalidateMenuState()
            }
            .store(in: &cancellables)

        settings.$recordingMode
            .dropFirst()
            .sink { [weak self] _ in
                self?.statusItem.button?.toolTip = self?.holdTooltip
                self?.invalidateMenuState()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(settings.$outputMode, settings.$translationTargetLanguage, settings.$personalDictionary)
            .dropFirst()
            .sink { [weak self] _ in
                self?.invalidateMenuState()
            }
            .store(in: &cancellables)
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
        let menuState = MenuState(
            language: settings.selectedLanguage,
            llmEnabled: settings.llmEnabled,
            llmConfigured: settings.llmConfiguration != nil,
            outputMode: settings.outputMode,
            translationTargetLanguage: settings.translationTargetLanguage,
            recordingMode: settings.recordingMode,
            activationHotkey: settings.activationHotkey,
            historySignature: historyStore.items.first?.id.uuidString ?? "",
            hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable,
            lastUserMessage: lastUserMessage
        )
        guard menuState != lastRenderedMenuState else { return }
        lastRenderedMenuState = menuState

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

        let outputModeItem = NSMenuItem(title: localizedOutputModeMenuTitle(), action: nil, keyEquivalent: "")
        let outputModeMenu = NSMenu()
        for mode in VoiceOutputMode.allCases {
            let item = NSMenuItem(title: mode.title(for: settings.selectedLanguage), action: #selector(selectOutputMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == settings.outputMode ? .on : .off
            outputModeMenu.addItem(item)
        }
        outputModeItem.submenu = outputModeMenu
        llmMenu.addItem(outputModeItem)

        let targetLanguageItem = NSMenuItem(title: localizedTranslationTargetMenuTitle(), action: nil, keyEquivalent: "")
        let targetLanguageMenu = NSMenu()
        for language in LanguageOption.allCases {
            let item = NSMenuItem(title: language.title, action: #selector(selectTranslationTargetLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = language == settings.translationTargetLanguage ? .on : .off
            targetLanguageMenu.addItem(item)
        }
        targetLanguageItem.submenu = targetLanguageMenu
        llmMenu.addItem(targetLanguageItem)

        let settingsItem = NSMenuItem(title: strings.settings, action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)
        llmMenuItem.submenu = llmMenu
        menu.addItem(llmMenuItem)

        let recordingModeItem = NSMenuItem(title: localizedRecordingModeMenuTitle(), action: nil, keyEquivalent: "")
        let recordingModeMenu = NSMenu()
        for mode in RecordingMode.allCases {
            let item = NSMenuItem(title: mode.title(for: settings.selectedLanguage), action: #selector(selectRecordingMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == settings.recordingMode ? .on : .off
            recordingModeMenu.addItem(item)
        }
        recordingModeItem.submenu = recordingModeMenu
        menu.addItem(recordingModeItem)

        let hotkeyItem = NSMenuItem(title: localizedActivationHotkeyMenuTitle(), action: nil, keyEquivalent: "")
        let hotkeyMenu = NSMenu()
        for hotkey in ActivationHotkey.allCases {
            let item = NSMenuItem(title: hotkey.title(for: settings.selectedLanguage), action: #selector(selectActivationHotkey(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = hotkey.rawValue
            item.state = hotkey == settings.activationHotkey ? .on : .off
            hotkeyMenu.addItem(item)
        }
        hotkeyItem.submenu = hotkeyMenu
        menu.addItem(hotkeyItem)

        let historyItem = NSMenuItem(title: localizedHistoryMenuTitle(), action: nil, keyEquivalent: "")
        historyItem.submenu = makeHistoryMenu()
        menu.addItem(historyItem)

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
        statusItem.button?.toolTip = holdTooltip
        floatingPanel.setLanguage(language)
        invalidateMenuState()
    }

    @objc
    private func toggleLLM(_ sender: NSMenuItem) {
        guard settings.llmConfiguration != nil else {
            showUserMessage(strings.configureAPISettingsFirst)
            return
        }
        settings.llmEnabled.toggle()
        invalidateMenuState()
    }

    @objc
    private func selectOutputMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let outputMode = VoiceOutputMode(rawValue: rawValue) else {
            return
        }
        settings.outputMode = outputMode
        invalidateMenuState()
    }

    @objc
    private func selectTranslationTargetLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = LanguageOption(rawValue: rawValue) else {
            return
        }
        settings.translationTargetLanguage = language
        invalidateMenuState()
    }

    @objc
    private func selectRecordingMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = RecordingMode(rawValue: rawValue) else {
            return
        }
        settings.recordingMode = mode
        statusItem.button?.toolTip = holdTooltip
        invalidateMenuState()
    }

    @objc
    private func selectActivationHotkey(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let hotkey = ActivationHotkey(rawValue: rawValue) else {
            return
        }
        settings.activationHotkey = hotkey
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
            hotkeyMonitor.refresh(activationHotkey: settings.activationHotkey)
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
                openOnboardingGuide()
                return
            }

            let sessionID = UUID()
            captureState = .starting(sessionID)
            pendingStopSessionID = nil
            lastUserMessage = nil
            floatingPanel.showListening()

            do {
                try await speechRecognizer.start(
                    language: settings.selectedLanguage,
                    contextualStrings: settings.personalDictionaryTerms
                )
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

    private func handleActivationPressed() {
        switch settings.recordingMode {
        case .holdToRecord:
            beginRecording()
        case .toggleToRecord:
            switch captureState {
            case .idle:
                beginRecording()
            case .starting, .recording:
                finishRecording()
            case .processing:
                return
            }
        }
    }

    private func handleActivationReleased() {
        guard settings.recordingMode == .holdToRecord else { return }
        finishRecording()
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
            if settings.llmEnabled, settings.outputMode.requiresLLM, let configuration = settings.llmConfiguration {
                floatingPanel.showRefining(with: transcript)
                do {
                    finalText = try await refineWithTimeout(
                        text: transcript,
                        configuration: configuration,
                        options: settings.voiceProcessingOptions
                    )
                } catch {
                    if let refinementError = error as? RefinementError, refinementError == .timeout {
                        showUserMessage(strings.llmTimedOutFallback)
                    } else {
                        showUserMessage(strings.llmFailedFallback)
                    }
                    finalText = transcript
                }
            }

            historyStore.add(rawTranscript: transcript, finalText: finalText, options: settings.voiceProcessingOptions)
            await textInjector.inject(finalText)
            invalidateMenuState()
            floatingPanel.hide()
        }
    }

    private func refineWithTimeout(text: String, configuration: LLMConfiguration, options: VoiceProcessingOptions) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.llmRefiner.refine(text: text, configuration: configuration, options: options)
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
        scheduleMenuRebuild()
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
        hotkeyMonitor.refresh(activationHotkey: settings.activationHotkey)
        var diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
        if diagnostics.microphone == .notDetermined || diagnostics.speechRecognition == .notDetermined {
            NSApp.activate(ignoringOtherApps: true)
            await speechRecognizer.requestPermissions()
            try? await Task.sleep(for: .milliseconds(250))
            hotkeyMonitor.refresh(activationHotkey: settings.activationHotkey)
            diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
            invalidateMenuState()
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
        hotkeyMonitor.refresh(activationHotkey: settings.activationHotkey)
        let diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
        invalidateMenuState()
        return diagnostics
    }

    private func scheduleMenuRebuild() {
        rebuildMenuTask?.cancel()
        rebuildMenuTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: MenuRefresh.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            self?.rebuildMenu()
        }
    }

    private func invalidateMenuState() {
        lastRenderedMenuState = nil
        scheduleMenuRebuild()
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
        case .denied:
            return "⚠"
        }
    }

    private func statusColor(for state: PermissionState) -> NSColor {
        switch state {
        case .granted:
            return .systemGreen
        case .notDetermined:
            return .systemYellow
        case .denied:
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

    private func localizedOutputModeMenuTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "Output Mode"
        case .simplifiedChinese: return "输出模式"
        case .traditionalChinese: return "輸出模式"
        case .japanese: return "出力モード"
        case .korean: return "출력 모드"
        }
    }

    private func localizedTranslationTargetMenuTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "Translation Target"
        case .simplifiedChinese: return "翻译目标语言"
        case .traditionalChinese: return "翻譯目標語言"
        case .japanese: return "翻訳先言語"
        case .korean: return "번역 대상 언어"
        }
    }

    private var holdTooltip: String {
        let key = settings.activationHotkey.title(for: settings.selectedLanguage)
        switch settings.recordingMode {
        case .holdToRecord:
            switch settings.selectedLanguage {
            case .english: return "Hold \(key) to record voice input"
            case .simplifiedChinese: return "按住 \(key) 开始语音输入"
            case .traditionalChinese: return "按住 \(key) 開始語音輸入"
            case .japanese: return "\(key) を押し続けて音声入力"
            case .korean: return "\(key) 키를 길게 눌러 음성 입력"
            }
        case .toggleToRecord:
            switch settings.selectedLanguage {
            case .english: return "Tap \(key) to start or stop voice input"
            case .simplifiedChinese: return "按一下 \(key) 开始或结束语音输入"
            case .traditionalChinese: return "按一下 \(key) 開始或結束語音輸入"
            case .japanese: return "\(key) を押して音声入力を開始/停止"
            case .korean: return "\(key) 키를 눌러 음성 입력 시작/중지"
            }
        }
    }

    private func localizedRecordingModeMenuTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "Recording Mode"
        case .simplifiedChinese: return "录音模式"
        case .traditionalChinese: return "錄音模式"
        case .japanese: return "録音モード"
        case .korean: return "녹음 모드"
        }
    }

    private func localizedActivationHotkeyMenuTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "Activation Hotkey"
        case .simplifiedChinese: return "触发快捷键"
        case .traditionalChinese: return "觸發快捷鍵"
        case .japanese: return "起動キー"
        case .korean: return "활성화 단축키"
        }
    }

    private func localizedHistoryMenuTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "History"
        case .simplifiedChinese: return "历史记录"
        case .traditionalChinese: return "歷史記錄"
        case .japanese: return "履歴"
        case .korean: return "기록"
        }
    }

    private func makeHistoryMenu() -> NSMenu {
        let menu = NSMenu()
        guard !historyStore.items.isEmpty else {
            let emptyItem = NSMenuItem(title: localizedEmptyHistoryTitle(), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return menu
        }

        for item in historyStore.items.prefix(10) {
            let menuItem = NSMenuItem(title: historyTitle(for: item), action: #selector(copyHistoryItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item.id.uuidString
            menu.addItem(menuItem)
        }
        menu.addItem(.separator())
        let clearItem = NSMenuItem(title: localizedClearHistoryTitle(), action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        return menu
    }

    @objc
    private func copyHistoryItem(_ sender: NSMenuItem) {
        guard let rawID = sender.representedObject as? String,
              let id = UUID(uuidString: rawID),
              let item = historyStore.item(with: id) else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.finalText, forType: .string)
        showUserMessage(localizedCopiedHistoryTitle())
    }

    @objc
    private func clearHistory() {
        historyStore.clear()
        showUserMessage(localizedHistoryClearedTitle())
        invalidateMenuState()
    }

    private func historyTitle(for item: DictationHistoryItem) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let mode = item.outputMode.title(for: settings.selectedLanguage)
        return "\(formatter.string(from: item.createdAt)) · \(mode) · \(historyStore.preview(for: item))"
    }

    private func localizedEmptyHistoryTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "No history yet"
        case .simplifiedChinese: return "暂无历史记录"
        case .traditionalChinese: return "暫無歷史記錄"
        case .japanese: return "履歴はまだありません"
        case .korean: return "기록이 아직 없습니다"
        }
    }

    private func localizedClearHistoryTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "Clear History"
        case .simplifiedChinese: return "清空历史记录"
        case .traditionalChinese: return "清空歷史記錄"
        case .japanese: return "履歴を消去"
        case .korean: return "기록 지우기"
        }
    }

    private func localizedCopiedHistoryTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "Copied history item."
        case .simplifiedChinese: return "已复制历史记录。"
        case .traditionalChinese: return "已複製歷史記錄。"
        case .japanese: return "履歴項目をコピーしました。"
        case .korean: return "기록 항목을 복사했습니다."
        }
    }

    private func localizedHistoryClearedTitle() -> String {
        switch settings.selectedLanguage {
        case .english: return "History cleared."
        case .simplifiedChinese: return "历史记录已清空。"
        case .traditionalChinese: return "歷史記錄已清空。"
        case .japanese: return "履歴を消去しました。"
        case .korean: return "기록을 지웠습니다."
        }
    }
}

private struct MenuState: Equatable {
    let language: LanguageOption
    let llmEnabled: Bool
    let llmConfigured: Bool
    let outputMode: VoiceOutputMode
    let translationTargetLanguage: LanguageOption
    let recordingMode: RecordingMode
    let activationHotkey: ActivationHotkey
    let historySignature: String
    let hotkeyMonitorAvailable: Bool
    let lastUserMessage: String?
}
