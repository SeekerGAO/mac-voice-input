import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let settings: SettingsStore
    private let hotkeyMonitor: HotkeyMonitor

    init(settings: SettingsStore, hotkeyMonitor: HotkeyMonitor) {
        self.settings = settings
        self.hotkeyMonitor = hotkeyMonitor
        let view = OnboardingView(settings: settings, hotkeyMonitor: hotkeyMonitor)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "首次启动引导"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 560, height: 460))
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

private struct OnboardingView: View {
    @ObservedObject var settings: SettingsStore
    let hotkeyMonitor: HotkeyMonitor
    @State private var diagnostics: PermissionDiagnostics

    init(settings: SettingsStore, hotkeyMonitor: HotkeyMonitor) {
        self.settings = settings
        self.hotkeyMonitor = hotkeyMonitor
        _diagnostics = State(initialValue: PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("首次启动需要完成权限设置")
                .font(.system(size: 24, weight: .semibold))

            Text("为了实现全局 Fn 录音、语音识别和自动粘贴，应用需要你授权麦克风、语音识别、辅助功能和输入监控。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                PermissionRow(title: "1. 麦克风", detail: "用于录音采集语音。", state: diagnostics.microphone)
                PermissionRow(title: "2. 语音识别", detail: "用于 Apple Speech 实时转写。", state: diagnostics.speechRecognition)
                PermissionRow(title: "3. 辅助功能", detail: "用于模拟粘贴和辅助输入控制。", state: diagnostics.accessibility)
                PermissionRow(title: "4. 输入监控", detail: "用于全局监听 Fn 键。这里是根据事件监听是否可用进行推断。", state: diagnostics.inputMonitoring)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("建议操作顺序")
                    .font(.headline)
                Text("1. 点击“打开系统隐私设置”")
                Text("2. 依次在“隐私与安全性”中完成授权")
                Text("3. 回到应用后点击“刷新状态”")
                Text("4. 所有关键权限显示为 Granted 后即可正常使用")
            }

            HStack(spacing: 12) {
                Button("打开系统隐私设置") {
                    PermissionDiagnosticsService.openPrivacySettings()
                }

                Button("刷新状态") {
                    diagnostics = PermissionDiagnosticsService.current(hotkeyMonitorAvailable: hotkeyMonitor.isMonitoringAvailable)
                }

                Spacer()

                if diagnostics.hasBlockingIssue {
                    Text("仍有权限未就绪")
                        .foregroundStyle(.orange)
                } else {
                    Text("权限状态已就绪")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let state: PermissionState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(title) · \(state.title)")
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 13))
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
        case .denied, .inferredUnavailable:
            return .red
        }
    }
}
