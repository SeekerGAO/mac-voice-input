import Accelerate
import AVFoundation
import Foundation
import Speech

enum SpeechRecognizerError: LocalizedError {
    case speechAuthorizationDenied
    case microphoneAuthorizationDenied
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .speechAuthorizationDenied:
            return "Speech recognition permission was denied."
        case .microphoneAuthorizationDenied:
            return "Microphone permission was denied."
        case .recognizerUnavailable:
            return "Speech recognizer is unavailable for the selected language."
        }
    }
}

final class SpeechRecognizerService: @unchecked Sendable {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private let weights: [Float] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private let transcriptLock = NSLock()

    var onTranscript: ((String) -> Void)?
    var onMeter: (([CGFloat]) -> Void)?

    var microphonePermissionState: PermissionState {
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

    var speechPermissionState: PermissionState {
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

    func requestPermissions() async {
        if speechPermissionState == .notDetermined {
            _ = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in
                    Task { @MainActor in
                        continuation.resume(returning: ())
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(200))
        }

        if microphonePermissionState == .notDetermined {
            _ = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    Task { @MainActor in
                        continuation.resume(returning: granted)
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    func start(language: LanguageOption) async throws {
        try await requestPermissionsIfNeeded()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        setLatestTranscript("")

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue)),
              recognizer.isAvailable else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString
                self.setLatestTranscript(transcript)
                let onTranscript = self.onTranscript
                DispatchQueue.main.async {
                    onTranscript?(transcript)
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                let audioEngine = self.audioEngine
                DispatchQueue.main.async {
                    audioEngine.stop()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        var meterEnvelope: Float = 0.1
        let weights = self.weights
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, request] buffer, _ in
            guard let self else { return }
            request.append(buffer)
            let bars = Self.makeMeterLevels(from: buffer, weights: weights, envelope: &meterEnvelope)
            let onMeter = self.onMeter
            DispatchQueue.main.async {
                onMeter?(bars)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() async -> String {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        try? await Task.sleep(for: .milliseconds(320))
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
        return latestTranscriptValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestPermissionsIfNeeded() async throws {
        if speechPermissionState == .notDetermined {
            _ = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in
                    Task { @MainActor in
                        continuation.resume(returning: ())
                    }
                }
            }
        }
        let speechAuthorized = speechPermissionState == .granted
        guard speechAuthorized else {
            throw SpeechRecognizerError.speechAuthorizationDenied
        }

        if microphonePermissionState == .notDetermined {
            _ = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    Task { @MainActor in
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
        let micAuthorized = microphonePermissionState == .granted
        guard micAuthorized else {
            throw SpeechRecognizerError.microphoneAuthorizationDenied
        }
    }

    private static func makeMeterLevels(from buffer: AVAudioPCMBuffer, weights: [Float], envelope: inout Float) -> [CGFloat] {
        guard let samples = buffer.floatChannelData?.pointee else {
            return Array(repeating: 0.18, count: 5)
        }
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 {
            return Array(repeating: 0.18, count: 5)
        }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameLength))

        let normalized = min(max(rms * 12, 0), 1)
        let smoothing: Float = normalized > envelope ? 0.4 : 0.15
        envelope += (normalized - envelope) * smoothing

        return weights.map { weight in
            let jitter = Float.random(in: -0.04 ... 0.04)
            let level = min(max(0.18 + (envelope * weight * 0.82), 0.18), 1.0) * (1 + jitter)
            return CGFloat(min(max(level, 0.18), 1.0))
        }
    }

    private var latestTranscriptValue: String {
        transcriptLock.lock()
        defer { transcriptLock.unlock() }
        return latestTranscript
    }

    private func setLatestTranscript(_ transcript: String) {
        transcriptLock.lock()
        latestTranscript = transcript
        transcriptLock.unlock()
    }
}
