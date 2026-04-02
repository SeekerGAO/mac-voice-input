import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let settings: SettingsStore
    private let hotkeyMonitor: HotkeyMonitor
    private let onRefreshPermissions: @MainActor () async -> PermissionDiagnostics
    private let onRequestMediaPermissions: @MainActor () async -> PermissionDiagnostics

    init(
        settings: SettingsStore,
        hotkeyMonitor: HotkeyMonitor,
        onRefreshPermissions: @escaping @MainActor () async -> PermissionDiagnostics,
        onRequestMediaPermissions: @escaping @MainActor () async -> PermissionDiagnostics
    ) {
        self.settings = settings
        self.hotkeyMonitor = hotkeyMonitor
        self.onRefreshPermissions = onRefreshPermissions
        self.onRequestMediaPermissions = onRequestMediaPermissions
        let view = OnboardingView(
            settings: settings,
            hotkeyMonitor: hotkeyMonitor,
            onRefreshPermissions: onRefreshPermissions,
            onRequestMediaPermissions: onRequestMediaPermissions
        )
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "首次启动引导"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 620, height: 560))
        window.minSize = NSSize(width: 560, height: 500)
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

    func closeGuide() {
        window?.close()
    }
}

private struct OnboardingView: View {
    @ObservedObject var settings: SettingsStore
    let hotkeyMonitor: HotkeyMonitor
    let onRefreshPermissions: @MainActor () async -> PermissionDiagnostics
    let onRequestMediaPermissions: @MainActor () async -> PermissionDiagnostics
    @State private var diagnostics: PermissionDiagnostics
    @State private var isRefreshing = false
    @Environment(\.dismiss) private var dismiss

    init(
        settings: SettingsStore,
        hotkeyMonitor: HotkeyMonitor,
        onRefreshPermissions: @escaping @MainActor () async -> PermissionDiagnostics,
        onRequestMediaPermissions: @escaping @MainActor () async -> PermissionDiagnostics
    ) {
        self.settings = settings
        self.hotkeyMonitor = hotkeyMonitor
        self.onRefreshPermissions = onRefreshPermissions
        self.onRequestMediaPermissions = onRequestMediaPermissions
        _diagnostics = State(initialValue: PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable))
    }

    var body: some View {
        let strings = AppStrings(language: settings.selectedLanguage)
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(strings.firstRunHeadline)
                        .font(.system(size: 24, weight: .semibold))

                    Text(strings.firstRunIntro)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 12) {
                        StepCard(
                            step: localizedStepNumber(1, language: settings.selectedLanguage),
                            title: localizedOpenPrivacyTitle(for: settings.selectedLanguage),
                            detail: localizedOpenPrivacyDetail(for: settings.selectedLanguage),
                            accent: .blue
                        )
                        StepCard(
                            step: localizedStepNumber(2, language: settings.selectedLanguage),
                            title: localizedGrantPermissionsTitle(for: settings.selectedLanguage),
                            detail: localizedGrantPermissionsDetail(for: settings.selectedLanguage),
                            accent: .orange
                        )
                        StepCard(
                            step: localizedStepNumber(3, language: settings.selectedLanguage),
                            title: localizedRecheckTitle(for: settings.selectedLanguage),
                            detail: localizedRecheckDetail(for: settings.selectedLanguage),
                            accent: .green
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(localizedPermissionStatusTitle(for: settings.selectedLanguage))
                            .font(.headline)

                        PermissionRow(title: localizedMicrophoneTitle(for: settings.selectedLanguage), detail: localizedMicrophoneDetail(for: settings.selectedLanguage), state: diagnostics.microphone, language: settings.selectedLanguage)
                        PermissionRow(title: localizedSpeechTitle(for: settings.selectedLanguage), detail: localizedSpeechDetail(for: settings.selectedLanguage), state: diagnostics.speechRecognition, language: settings.selectedLanguage)
                        PermissionRow(title: localizedAccessibilityTitle(for: settings.selectedLanguage), detail: localizedAccessibilityDetail(for: settings.selectedLanguage), state: diagnostics.accessibility, language: settings.selectedLanguage)
                        PermissionRow(title: localizedInputMonitoringTitle(for: settings.selectedLanguage), detail: localizedInputMonitoringDetail(for: settings.selectedLanguage), state: diagnostics.inputMonitoring, language: settings.selectedLanguage)
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button(strings.openPrivacySettings) {
                    PermissionDiagnosticsService.openPrivacySettings()
                }

                Button(strings.requestPermissionsButton) {
                    Task {
                        isRefreshing = true
                        diagnostics = await onRequestMediaPermissions()
                        isRefreshing = false
                    }
                }

                Spacer()

                if diagnostics.hasBlockingIssue {
                    Text(localizedNotReadyText(for: settings.selectedLanguage))
                        .foregroundStyle(.orange)
                } else {
                    Text(localizedReadyText(for: settings.selectedLanguage))
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 12) {
                Button(localizedRecheckButton(for: settings.selectedLanguage)) {
                    Task {
                        isRefreshing = true
                        diagnostics = await onRefreshPermissions()
                        isRefreshing = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if isRefreshing {
                    Text(strings.refreshingPermissions)
                        .foregroundStyle(.secondary)
                }

                if !diagnostics.hasBlockingIssue {
                    Button(localizedStartUsingButton(for: settings.selectedLanguage)) {
                        settings.hasSeenOnboarding = true
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }

        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 500)
    }

    private func localizedStepNumber(_ number: Int, language: LanguageOption) -> String {
        switch language {
        case .english: return "Step \(number)"
        case .simplifiedChinese: return "步骤 \(number)"
        case .traditionalChinese: return "步驟 \(number)"
        case .japanese: return "手順 \(number)"
        case .korean: return "단계 \(number)"
        }
    }

    private func localizedOpenPrivacyTitle(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Open Privacy Settings"
        case .simplifiedChinese: return "打开系统隐私设置"
        case .traditionalChinese: return "打開系統隱私設定"
        case .japanese: return "プライバシー設定を開く"
        case .korean: return "개인정보 보호 설정 열기"
        }
    }

    private func localizedOpenPrivacyDetail(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Open Privacy & Security and prepare to grant access."
        case .simplifiedChinese: return "进入“隐私与安全性”，准备授权应用。"
        case .traditionalChinese: return "進入「隱私與安全性」，準備授權應用。"
        case .japanese: return "「プライバシーとセキュリティ」を開いて権限付与を準備します。"
        case .korean: return "개인정보 보호 및 보안을 열고 권한 허용을 준비하세요."
        }
    }

    private func localizedGrantPermissionsTitle(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Grant 4 permissions"
        case .simplifiedChinese: return "完成 4 项授权"
        case .traditionalChinese: return "完成 4 項授權"
        case .japanese: return "4 つの権限を許可"
        case .korean: return "4개 권한 허용"
        }
    }

    private func localizedGrantPermissionsDetail(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Microphone, Speech Recognition, Accessibility, and Input Monitoring."
        case .simplifiedChinese: return "麦克风、语音识别、辅助功能、输入监控。"
        case .traditionalChinese: return "麥克風、語音辨識、輔助使用、輸入監控。"
        case .japanese: return "マイク、音声認識、アクセシビリティ、入力監視。"
        case .korean: return "마이크, 음성 인식, 손쉬운 사용, 입력 모니터링."
        }
    }

    private func localizedRecheckTitle(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Return and recheck"
        case .simplifiedChinese: return "回到应用重新检查"
        case .traditionalChinese: return "回到應用重新檢查"
        case .japanese: return "アプリに戻って再確認"
        case .korean: return "앱으로 돌아와 다시 확인"
        }
    }

    private func localizedRecheckDetail(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Use the main button below to confirm everything is ready."
        case .simplifiedChinese: return "授权后点击下方主按钮，确认权限是否全部就绪。"
        case .traditionalChinese: return "授權後點擊下方主按鈕，確認權限是否全部就緒。"
        case .japanese: return "許可後に下のメインボタンで準備完了か確認します。"
        case .korean: return "권한 허용 후 아래 기본 버튼으로 준비 상태를 확인하세요."
        }
    }

    private func localizedPermissionStatusTitle(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Current permission status"
        case .simplifiedChinese: return "当前权限状态"
        case .traditionalChinese: return "目前權限狀態"
        case .japanese: return "現在の権限状態"
        case .korean: return "현재 권한 상태"
        }
    }

    private func localizedMicrophoneTitle(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Microphone"
        case .simplifiedChinese: return "麦克风"
        case .traditionalChinese: return "麥克風"
        case .japanese: return "マイク"
        case .korean: return "마이크"
        }
    }

    private func localizedMicrophoneDetail(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Capture audio for recording"
        case .simplifiedChinese: return "录音采集语音"
        case .traditionalChinese: return "錄音採集語音"
        case .japanese: return "録音用の音声を取得"
        case .korean: return "녹음용 음성 수집"
        }
    }

    private func localizedSpeechTitle(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Speech Recognition"
        case .simplifiedChinese: return "语音识别"
        case .traditionalChinese: return "語音辨識"
        case .japanese: return "音声認識"
        case .korean: return "음성 인식"
        }
    }

    private func localizedSpeechDetail(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Real-time Apple Speech transcription"
        case .simplifiedChinese: return "Apple Speech 实时转写"
        case .traditionalChinese: return "Apple Speech 即時轉寫"
        case .japanese: return "Apple Speech のリアルタイム変換"
        case .korean: return "Apple Speech 실시간 변환"
        }
    }

    private func localizedAccessibilityTitle(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Accessibility"
        case .simplifiedChinese: return "辅助功能"
        case .traditionalChinese: return "輔助使用"
        case .japanese: return "アクセシビリティ"
        case .korean: return "손쉬운 사용"
        }
    }

    private func localizedAccessibilityDetail(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Used for paste simulation and input control"
        case .simplifiedChinese: return "模拟粘贴和辅助输入控制"
        case .traditionalChinese: return "模擬貼上與輸入控制"
        case .japanese: return "貼り付け操作と入力制御に使用"
        case .korean: return "붙여넣기 시뮬레이션과 입력 제어에 사용"
        }
    }

    private func localizedInputMonitoringTitle(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Input Monitoring"
        case .simplifiedChinese: return "输入监控"
        case .traditionalChinese: return "輸入監控"
        case .japanese: return "入力監視"
        case .korean: return "입력 모니터링"
        }
    }

    private func localizedInputMonitoringDetail(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Global Fn key listening (inferred)"
        case .simplifiedChinese: return "全局监听 Fn 键（推断）"
        case .traditionalChinese: return "全域監聽 Fn 鍵（推斷）"
        case .japanese: return "グローバル Fn 監視（推定）"
        case .korean: return "전역 Fn 감지(추정)"
        }
    }

    private func localizedNotReadyText(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Permissions are still incomplete"
        case .simplifiedChinese: return "仍有权限未就绪"
        case .traditionalChinese: return "仍有權限未就緒"
        case .japanese: return "まだ権限が不足しています"
        case .korean: return "아직 권한이 부족합니다"
        }
    }

    private func localizedReadyText(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Permissions are ready"
        case .simplifiedChinese: return "权限状态已就绪"
        case .traditionalChinese: return "權限狀態已就緒"
        case .japanese: return "権限の準備が完了しました"
        case .korean: return "권한이 준비되었습니다"
        }
    }

    private func localizedRecheckButton(for language: LanguageOption) -> String {
        switch language {
        case .english: return "I've finished, recheck"
        case .simplifiedChinese: return "我已完成授权，重新检查"
        case .traditionalChinese: return "我已完成授權，重新檢查"
        case .japanese: return "許可後に再確認"
        case .korean: return "권한 허용 후 다시 확인"
        }
    }

    private func localizedStartUsingButton(for language: LanguageOption) -> String {
        switch language {
        case .english: return "Start Using"
        case .simplifiedChinese: return "开始使用"
        case .traditionalChinese: return "開始使用"
        case .japanese: return "使い始める"
        case .korean: return "사용 시작"
        }
    }
}

private struct StepCard: View {
    let step: String
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accent, in: Capsule())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let state: PermissionState
    let language: LanguageOption

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(state.title(for: language))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var color: Color {
        switch state {
        case .granted:
            return .green
        case .notDetermined:
            return .yellow
        case .denied:
            return .red
        }
    }
}
