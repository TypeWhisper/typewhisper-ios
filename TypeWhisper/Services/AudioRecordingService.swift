import Foundation
@preconcurrency import AVFoundation
import UIKit
import Combine
import os

final class AudioRecordingService: ObservableObject, @unchecked Sendable {

    enum AudioRecordingError: LocalizedError {
        case microphonePermissionDenied
        case engineStartFailed(String)
        case noAudioData

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                "Microphone permission denied. Please grant access in Settings."
            case .engineStartFailed(let detail):
                "Failed to start audio engine: \(detail)"
            case .noAudioData:
                "No audio data was recorded."
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var isSilent: Bool = false
    @Published private(set) var silenceDuration: TimeInterval = 0
    @Published var didAutoStop: Bool = false

    var silenceThreshold: Float = 0.01
    var silenceAutoStopDuration: TimeInterval = 0
    var gainMultiplier: Float = 1.0

    private var audioEngine: AVAudioEngine?
    private var sampleBuffer: [Float] = []
    private let bufferLock = NSLock()
    private var silenceStart: Date?
    private let processingQueue = DispatchQueue(label: "com.typewhisper.audio-processing", qos: .userInteractive)

    static let targetSampleRate: Double = 16000

    var hasMicrophonePermission: Bool {
        AVAudioSession.sharedInstance().recordPermission == .granted
    }

    func requestMicrophonePermission() async -> Bool {
        let permission = AVAudioSession.sharedInstance().recordPermission
        if permission == .granted { return true }
        if permission == .undetermined {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        // .denied — open Settings
        await MainActor.run {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        return false
    }

    func getCurrentBuffer() -> [Float] {
        bufferLock.lock()
        let copy = sampleBuffer
        bufferLock.unlock()
        return copy
    }

    func startRecording() throws {
        guard hasMicrophonePermission else {
            throw AudioRecordingError.microphonePermissionDenied
        }

        // Configure audio session for recording
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioRecordingError.engineStartFailed("No audio input available")
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecordingError.engineStartFailed("Cannot create target audio format")
        }

        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        guard let converter else {
            throw AudioRecordingError.engineStartFailed("Cannot create audio converter")
        }

        bufferLock.lock()
        sampleBuffer.removeAll()
        bufferLock.unlock()

        silenceStart = nil
        isSilent = false
        silenceDuration = 0
        didAutoStop = false

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioRecordingError.engineStartFailed(error.localizedDescription)
        }

        audioEngine = engine
        isRecording = true
    }

    func stopRecording() -> [Float] {
        let engine = audioEngine
        audioEngine = nil
        isRecording = false
        audioLevel = 0
        isSilent = false
        silenceDuration = 0
        silenceStart = nil

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()

        bufferLock.lock()
        let samples = sampleBuffer
        sampleBuffer.removeAll()
        bufferLock.unlock()

        // Deactivate audio session after engine is fully stopped
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }

        return samples
    }

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * Self.targetSampleRate / buffer.format.sampleRate
        )
        guard frameCount > 0 else { return }

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCount
        ) else { return }

        var error: NSError?
        let consumed = OSAllocatedUnfairLock(initialState: false)

        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
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
            return buffer
        }

        guard error == nil, convertedBuffer.frameLength > 0 else { return }
        guard let channelData = convertedBuffer.floatChannelData?[0] else { return }

        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))

        processingQueue.async { [weak self] in
            self?.processConvertedSamples(samples)
        }
    }

    private func processConvertedSamples(_ rawSamples: [Float]) {
        var samples = rawSamples

        if gainMultiplier != 1.0 {
            for i in samples.indices {
                samples[i] = max(-1.0, min(1.0, samples[i] * gainMultiplier))
            }
        }

        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
        let normalizedLevel = min(1.0, rms * 5)
        let silent = rms < silenceThreshold

        bufferLock.lock()
        sampleBuffer.append(contentsOf: samples)
        bufferLock.unlock()

        let now = Date()
        let capturedSilenceStart = silenceStart

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.audioLevel = normalizedLevel

            if silent {
                if self.silenceStart == nil {
                    self.silenceStart = now
                }
                if let start = self.silenceStart ?? capturedSilenceStart {
                    self.silenceDuration = now.timeIntervalSince(start)
                }
                self.isSilent = true
            } else {
                self.silenceStart = nil
                self.silenceDuration = 0
                self.isSilent = false
            }
        }
    }
}
