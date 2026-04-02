import AppKit
import AVFoundation
import ApplicationServices
import Foundation
import Speech

enum PermissionState {
    case granted
    case denied
    case notDetermined

    var title: String {
        switch self {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        }
    }
}

struct PermissionDiagnostics {
    let microphone: PermissionState
    let speechRecognition: PermissionState
    let accessibility: PermissionState
    let inputMonitoring: PermissionState

    var hasBlockingIssue: Bool {
        [microphone, speechRecognition, accessibility, inputMonitoring].contains { state in
            state == .denied
        }
    }
}

enum PermissionDiagnosticsService {
    static func current(hotkeyMonitorAvailable: Bool) -> PermissionDiagnostics {
        PermissionDiagnostics(
            microphone: microphoneState(),
            speechRecognition: speechState(),
            accessibility: accessibilityState(),
            inputMonitoring: inputMonitoringState(hotkeyMonitorAvailable: hotkeyMonitorAvailable)
        )
    }

    static func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @discardableResult
    @MainActor
    static func requestAccessibilityPermission() -> PermissionState {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestPostEventAccess()
        return accessibilityState()
    }

    @discardableResult
    @MainActor
    static func requestInputMonitoringPermission() -> PermissionState {
        _ = CGRequestListenEventAccess()
        return inputMonitoringState(hotkeyMonitorAvailable: false)
    }

    private static func microphoneState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    private static func speechState() -> PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    private static func accessibilityState() -> PermissionState {
        if AXIsProcessTrusted() || CGPreflightPostEventAccess() {
            return .granted
        }
        return .denied
    }

    private static func inputMonitoringState(hotkeyMonitorAvailable: Bool) -> PermissionState {
        if CGPreflightListenEventAccess() || hotkeyMonitorAvailable {
            return .granted
        }
        return .denied
    }
}
