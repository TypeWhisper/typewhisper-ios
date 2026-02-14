import Foundation
@preconcurrency import AVFoundation
import UIKit
import os.log

/// Calculate audio levels from buffer — free function to avoid @MainActor metatype isolation
private func calculateFlowAudioLevels(from buffer: AVAudioPCMBuffer, barCount: Int) -> [Float] {
    guard let channelData = buffer.floatChannelData else {
        return Array(repeating: 0, count: barCount)
    }

    let frameLength = Int(buffer.frameLength)
    guard frameLength > 0 else {
        return Array(repeating: 0, count: barCount)
    }

    let samplesPerBar = frameLength / barCount
    var levels = [Float]()

    for barIndex in 0..<barCount {
        let startSample = barIndex * samplesPerBar
        let endSample = min(startSample + samplesPerBar, frameLength)

        var sum: Float = 0
        for i in startSample..<endSample {
            let sample = channelData[0][i]
            sum += abs(sample)
        }

        let avgLevel = sum / Float(endSample - startSample)
        let normalizedLevel = min(avgLevel * 50.0, 1.0)
        levels.append(normalizedLevel)
    }

    return levels
}

/// Thread-safe audio buffer store for flow recording
private final class FlowAudioBufferStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _buffers: [AVAudioPCMBuffer] = []

    func append(_ buffer: AVAudioPCMBuffer, maxSamples: Int) {
        lock.lock()
        _buffers.append(buffer)
        var totalSamples = _buffers.reduce(0) { $0 + Int($1.frameLength) }
        while totalSamples > maxSamples && _buffers.count > 1 {
            let removed = _buffers.removeFirst()
            totalSamples -= Int(removed.frameLength)
        }
        lock.unlock()
    }

    var buffers: [AVAudioPCMBuffer] {
        lock.lock()
        defer { lock.unlock() }
        return _buffers
    }

    func removeAll() {
        lock.lock()
        _buffers.removeAll()
        lock.unlock()
    }
}

/// Install audio tap from a nonisolated context — closures defined inside @MainActor methods
/// inherit actor isolation in Swift 6 and crash on the audio thread.
private func installFlowAudioTap(
    on inputNode: AVAudioNode,
    format: AVAudioFormat,
    recordingFlag: OSAllocatedUnfairLock<Bool>,
    defaults: UserDefaults?,
    bufferStore: FlowAudioBufferStore,
    maxSamples: Int
) {
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
        let currentlyRecording = recordingFlag.withLock { $0 }

        let levels = calculateFlowAudioLevels(from: buffer, barCount: 24)
        let levelsAsDouble = levels.map { Double($0) }
        defaults?.set(levelsAsDouble, forKey: TypeWhisperConstants.SharedDefaults.audioLevels)
        defaults?.synchronize()

        guard currentlyRecording else { return }

        if let bufferCopy = copyFlowAudioBuffer(buffer) {
            bufferStore.append(bufferCopy, maxSamples: maxSamples)
        }
    }
}

/// Copy audio buffer — free function to avoid @MainActor metatype isolation
private func copyFlowAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
        return nil
    }
    copy.frameLength = buffer.frameLength

    if let srcData = buffer.floatChannelData, let dstData = copy.floatChannelData {
        for channel in 0..<Int(buffer.format.channelCount) {
            memcpy(dstData[channel], srcData[channel], Int(buffer.frameLength) * MemoryLayout<Float>.size)
        }
    }
    return copy
}

/// Manages "Flow Sessions" — the main app continuously records audio in the background
/// and the keyboard extension signals when to transcribe via shared UserDefaults.
/// Uses local WhisperKit transcription instead of API calls.
@MainActor
class FlowSessionManager: ObservableObject {
    private let logger = Logger(subsystem: "com.typewhisper", category: "FlowSession")

    private let sharedDefaults = UserDefaults(suiteName: TypeWhisperConstants.appGroupIdentifier)
    private let modelManager: ModelManagerService

    @Published var isFlowSessionActive = false
    @Published var sessionExpiresAt: Date?
    @Published var isRecording = false
    @Published var lastTranscription: String?

    private var audioEngine: AVAudioEngine?
    private var sessionTimer: Timer?
    private var pollingTimer: Timer?

    private let isRecordingAtomic = OSAllocatedUnfairLock(initialState: false)
    private var recordingStartTime: Date?
    private let flowBufferStore = FlowAudioBufferStore()
    private var recordingFormat: AVAudioFormat?
    private let maxBufferDuration: TimeInterval = 60

    init(modelManager: ModelManagerService) {
        self.modelManager = modelManager
        checkExistingSession()
    }

    private func checkExistingSession() {
        guard let expires = sharedDefaults?.object(forKey: TypeWhisperConstants.SharedDefaults.flowSessionExpires) as? Date else {
            isFlowSessionActive = false
            return
        }

        if expires > Date() {
            isFlowSessionActive = true
            sessionExpiresAt = expires
            startFlowSession(duration: expires.timeIntervalSinceNow)
        } else {
            endFlowSession()
        }
    }

    // MARK: - Session Lifecycle

    func startFlowSession(duration: TimeInterval = 300) {
        logger.info("Starting Flow Session for \(duration) seconds")

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Failed to configure audio session: \(error)")
            return
        }

        sharedDefaults?.set("idle", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
        sharedDefaults?.removeObject(forKey: TypeWhisperConstants.SharedDefaults.transcriptionResult)
        sharedDefaults?.removeObject(forKey: TypeWhisperConstants.SharedDefaults.transcriptionError)
        sharedDefaults?.synchronize()

        startContinuousRecording()
        startPollingForKeyboardSignals()

        let expiresAt = Date().addingTimeInterval(duration)
        sessionExpiresAt = expiresAt
        isFlowSessionActive = true

        sharedDefaults?.set(true, forKey: TypeWhisperConstants.SharedDefaults.flowSessionActive)
        sharedDefaults?.set(expiresAt, forKey: TypeWhisperConstants.SharedDefaults.flowSessionExpires)
        sharedDefaults?.synchronize()

        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.endFlowSession() }
        }

        logger.info("Flow Session started, expires at \(expiresAt)")

        NotificationCenter.default.post(name: .flowSessionStartedFromKeyboard, object: nil)
    }

    func endFlowSession() {
        logger.info("Ending Flow Session")

        sessionTimer?.invalidate()
        sessionTimer = nil
        pollingTimer?.invalidate()
        pollingTimer = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        flowBufferStore.removeAll()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        isFlowSessionActive = false
        isRecording = false
        isRecordingAtomic.withLock { $0 = false }
        sessionExpiresAt = nil

        sharedDefaults?.set(false, forKey: TypeWhisperConstants.SharedDefaults.flowSessionActive)
        sharedDefaults?.removeObject(forKey: TypeWhisperConstants.SharedDefaults.flowSessionExpires)
        sharedDefaults?.set("idle", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
        sharedDefaults?.synchronize()
    }

    func extendFlowSession(by duration: TimeInterval = 300) {
        guard isFlowSessionActive else {
            startFlowSession(duration: duration)
            return
        }

        let newExpiration = Date().addingTimeInterval(duration)
        sessionExpiresAt = newExpiration
        sharedDefaults?.set(newExpiration, forKey: TypeWhisperConstants.SharedDefaults.flowSessionExpires)
        sharedDefaults?.synchronize()

        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.endFlowSession() }
        }
    }

    // MARK: - Audio Recording

    private func startContinuousRecording() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        recordingFormat = format

        flowBufferStore.removeAll()

        let maxSamples = Int(format.sampleRate * maxBufferDuration)
        installFlowAudioTap(
            on: inputNode,
            format: format,
            recordingFlag: isRecordingAtomic,
            defaults: sharedDefaults,
            bufferStore: flowBufferStore,
            maxSamples: maxSamples
        )

        do {
            engine.prepare()
            try engine.start()
        } catch {
            logger.error("Failed to start audio engine: \(error)")
        }
    }

    // MARK: - Keyboard Signal Polling

    private func startPollingForKeyboardSignals() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkKeyboardSignal() }
        }
    }

    private func checkKeyboardSignal() {
        guard let state = sharedDefaults?.string(forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState) else { return }

        switch state {
        case "recording":
            if !isRecording {
                isRecording = true
                isRecordingAtomic.withLock { $0 = true }
                recordingStartTime = Date()
                logger.info("Keyboard started recording")
            }

        case "stopped":
            if isRecording {
                isRecording = false
                isRecordingAtomic.withLock { $0 = false }
                logger.info("Keyboard stopped recording - starting transcription")

                sharedDefaults?.set("processing", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
                sharedDefaults?.synchronize()

                Task {
                    await transcribeRecordedAudio()
                }
            }

        default:
            break
        }
    }

    // MARK: - Transcription (Local WhisperKit)

    private func transcribeRecordedAudio() async {
        guard recordingStartTime != nil else {
            logger.error("No recording start time")
            sharedDefaults?.set("No recording", forKey: TypeWhisperConstants.SharedDefaults.transcriptionError)
            sharedDefaults?.set("idle", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
            sharedDefaults?.synchronize()
            return
        }

        let buffersToTranscribe = flowBufferStore.buffers
        guard !buffersToTranscribe.isEmpty, let format = recordingFormat else {
            logger.error("No audio buffers to transcribe")
            sharedDefaults?.set("No audio", forKey: TypeWhisperConstants.SharedDefaults.transcriptionError)
            sharedDefaults?.set("idle", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
            sharedDefaults?.synchronize()
            return
        }

        // Convert buffers to 16kHz Float samples for WhisperKit
        guard let samples = convertBuffersToSamples(buffersToTranscribe, format: format) else {
            logger.error("Failed to convert audio buffers")
            sharedDefaults?.set("Audio conversion failed", forKey: TypeWhisperConstants.SharedDefaults.transcriptionError)
            sharedDefaults?.set("idle", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
            sharedDefaults?.synchronize()
            return
        }

        let language = sharedDefaults?.string(forKey: TypeWhisperConstants.SharedDefaults.transcriptionLanguage)
        let effectiveLanguage = (language == "auto") ? nil : language

        do {
            let result = try await modelManager.transcribe(
                audioSamples: samples,
                language: effectiveLanguage,
                task: .transcribe
            )
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.info("Transcription result: \(text)")

            lastTranscription = text
            sharedDefaults?.set(text, forKey: TypeWhisperConstants.SharedDefaults.transcriptionResult)
            sharedDefaults?.removeObject(forKey: TypeWhisperConstants.SharedDefaults.transcriptionError)
            sharedDefaults?.set("idle", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
            sharedDefaults?.synchronize()
        } catch {
            logger.error("Transcription error: \(error)")
            sharedDefaults?.set(error.localizedDescription, forKey: TypeWhisperConstants.SharedDefaults.transcriptionError)
            sharedDefaults?.set("idle", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
            sharedDefaults?.synchronize()
        }

        flowBufferStore.removeAll()
        recordingStartTime = nil
    }

    /// Convert audio buffers to 16kHz mono Float samples for WhisperKit
    private func convertBuffersToSamples(_ buffers: [AVAudioPCMBuffer], format: AVAudioFormat) -> [Float]? {
        var totalFrames: AVAudioFrameCount = 0
        for buffer in buffers {
            totalFrames += buffer.frameLength
        }
        guard totalFrames > 0 else { return nil }

        // Combine all buffers into one
        guard let combinedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            return nil
        }

        var offset: AVAudioFrameCount = 0
        for buffer in buffers {
            if let srcData = buffer.floatChannelData, let dstData = combinedBuffer.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    memcpy(
                        dstData[channel].advanced(by: Int(offset)),
                        srcData[channel],
                        Int(buffer.frameLength) * MemoryLayout<Float>.size
                    )
                }
            }
            offset += buffer.frameLength
        }
        combinedBuffer.frameLength = totalFrames

        // Resample to 16kHz mono
        let targetSampleRate: Double = 16000
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else { return nil }

        guard let converter = AVAudioConverter(from: format, to: targetFormat) else { return nil }

        let ratio = targetSampleRate / format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(totalFrames) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            return nil
        }

        let consumed = OSAllocatedUnfairLock(initialState: false)
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            let wasConsumed = consumed.withLock { flag in
                let prev = flag
                flag = true
                return prev
            }
            if wasConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            return combinedBuffer
        }

        guard error == nil, outputBuffer.frameLength > 0,
              let channelData = outputBuffer.floatChannelData?[0] else {
            return nil
        }

        return Array(UnsafeBufferPointer(start: channelData, count: Int(outputBuffer.frameLength)))
    }

    // MARK: - URL Handling

    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "typewhisper" else { return false }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        switch url.host {
        case "startflow":
            var duration: TimeInterval = 300
            if let durationParam = components?.queryItems?.first(where: { $0.name == "duration" })?.value,
               let durationValue = TimeInterval(durationParam) {
                duration = durationValue
            }
            startFlowSession(duration: duration)
            return true

        case "endflow":
            endFlowSession()
            return true

        case "extendflow":
            var duration: TimeInterval = 300
            if let durationParam = components?.queryItems?.first(where: { $0.name == "duration" })?.value,
               let durationValue = TimeInterval(durationParam) {
                duration = durationValue
            }
            extendFlowSession(by: duration)
            return true

        default:
            return false
        }
    }
}

extension Notification.Name {
    static let flowSessionStartedFromKeyboard = Notification.Name("flowSessionStartedFromKeyboard")
}
