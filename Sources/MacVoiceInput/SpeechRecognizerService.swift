import Accelerate
import AVFoundation
import Foundation
import QuartzCore
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
    private enum UpdateInterval {
        static let transcript: TimeInterval = 0.12
        static let meter: TimeInterval = 1.0 / 30.0
    }

    private enum Meter {
        static let floor: CGFloat = 0.18
        static let count = 5
    }

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private let weights: [Float] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private let transcriptLock = NSLock()
    private let updateLock = NSLock()
    private var lastDeliveredTranscript = ""
    private var pendingTranscript = ""
    private var lastTranscriptDeliveryTime: CFTimeInterval = 0
    private var pendingTranscriptTask: DispatchWorkItem?
    private var lastMeterDeliveryTime: CFTimeInterval = 0

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

    func start(language: LanguageOption, contextualStrings: [String] = []) async throws {
        try await requestPermissionsIfNeeded()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        setLatestTranscript("")
        resetUpdateState()

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue)),
              recognizer.isAvailable else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        request.contextualStrings = contextualStrings
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString
                self.setLatestTranscript(transcript)
                self.scheduleTranscriptDelivery(transcript, immediate: result.isFinal)
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
        var meterPhase: Float = 0
        let weights = self.weights
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, request] buffer, _ in
            guard let self else { return }
            request.append(buffer)
            meterPhase += 0.22
            let bars = Self.makeMeterLevels(
                from: buffer,
                weights: weights,
                envelope: &meterEnvelope,
                phase: meterPhase
            )
            self.scheduleMeterDelivery(bars)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() async -> String {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        flushPendingTranscript()
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

    private static func makeMeterLevels(
        from buffer: AVAudioPCMBuffer,
        weights: [Float],
        envelope: inout Float,
        phase: Float
    ) -> [CGFloat] {
        guard let samples = buffer.floatChannelData?.pointee else {
            return Array(repeating: Meter.floor, count: Meter.count)
        }
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 {
            return Array(repeating: Meter.floor, count: Meter.count)
        }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameLength))

        let normalized = min(max(rms * 12, 0), 1)
        let smoothing: Float = normalized > envelope ? 0.4 : 0.15
        envelope += (normalized - envelope) * smoothing

        return weights.enumerated().map { index, weight in
            let baseLevel = Meter.floor + CGFloat(envelope * weight * 0.82)
            let wobble = CGFloat(sinf(phase + (Float(index) * 0.7)) * 0.025)
            let clampedLevel = min(1.0, max(Meter.floor, baseLevel + wobble))
            return clampedLevel
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

    private func resetUpdateState() {
        updateLock.lock()
        pendingTranscriptTask?.cancel()
        pendingTranscriptTask = nil
        pendingTranscript = ""
        lastDeliveredTranscript = ""
        lastTranscriptDeliveryTime = 0
        lastMeterDeliveryTime = 0
        updateLock.unlock()
    }

    private func flushPendingTranscript() {
        let transcript: String?
        updateLock.lock()
        pendingTranscriptTask?.cancel()
        pendingTranscriptTask = nil
        transcript = pendingTranscript.isEmpty ? nil : pendingTranscript
        pendingTranscript = ""
        updateLock.unlock()

        if let transcript {
            deliverTranscript(transcript)
        }
    }

    private func scheduleTranscriptDelivery(_ transcript: String, immediate: Bool) {
        let workItem: DispatchWorkItem?
        updateLock.lock()
        pendingTranscript = transcript
        pendingTranscriptTask?.cancel()

        let now = CACurrentMediaTime()
        let elapsed = now - lastTranscriptDeliveryTime
        if immediate || elapsed >= UpdateInterval.transcript {
            pendingTranscript = ""
            workItem = nil
        } else {
            let delay = UpdateInterval.transcript - elapsed
            let item = DispatchWorkItem { [weak self] in
                self?.flushPendingTranscript()
            }
            pendingTranscriptTask = item
            workItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
        updateLock.unlock()

        if workItem == nil {
            deliverTranscript(transcript)
        }
    }

    private func deliverTranscript(_ transcript: String) {
        let handler: ((String) -> Void)?
        updateLock.lock()
        guard transcript != lastDeliveredTranscript else {
            updateLock.unlock()
            return
        }
        lastDeliveredTranscript = transcript
        lastTranscriptDeliveryTime = CACurrentMediaTime()
        handler = onTranscript
        updateLock.unlock()

        DispatchQueue.main.async {
            handler?(transcript)
        }
    }

    private func scheduleMeterDelivery(_ bars: [CGFloat]) {
        let handler: (([CGFloat]) -> Void)?
        updateLock.lock()
        let now = CACurrentMediaTime()
        guard now - lastMeterDeliveryTime >= UpdateInterval.meter else {
            updateLock.unlock()
            return
        }
        lastMeterDeliveryTime = now
        handler = onMeter
        updateLock.unlock()

        DispatchQueue.main.async {
            handler?(bars)
        }
    }
}
