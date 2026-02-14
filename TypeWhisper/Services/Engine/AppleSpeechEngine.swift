import Foundation
import Speech
import AVFoundation

final class AppleSpeechEngine: TranscriptionEngine, @unchecked Sendable {
    let engineType: EngineType = .appleSpeech
    let supportsStreaming = false
    let supportsTranslation = false

    private(set) var isModelLoaded = false
    private var recognizer: SFSpeechRecognizer?

    var supportedLanguages: [String] {
        let locales = SFSpeechRecognizer.supportedLocales()
        let codes = Set(locales.compactMap { $0.language.languageCode?.identifier })
        return Array(codes).sorted()
    }

    func loadModel(_ model: ModelInfo, progress: @Sendable @escaping (Double, Double?) -> Void) async throws {
        guard model.engineType == .appleSpeech else {
            throw TranscriptionEngineError.modelLoadFailed("Not an Apple Speech model")
        }

        let status = SFSpeechRecognizer.authorizationStatus()

        if status == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus == .authorized)
                }
            }
            guard granted else {
                throw TranscriptionEngineError.modelLoadFailed("Speech recognition permission denied")
            }
        } else if status != .authorized {
            throw TranscriptionEngineError.modelLoadFailed("Speech recognition not authorized. Please enable in Settings.")
        }

        progress(0.5, nil)

        let rec = SFSpeechRecognizer()
        guard rec?.isAvailable == true else {
            throw TranscriptionEngineError.modelLoadFailed("Speech recognizer not available")
        }

        recognizer = rec
        isModelLoaded = true
        progress(1.0, nil)
    }

    func unloadModel() {
        recognizer = nil
        isModelLoaded = false
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask
    ) async throws -> TranscriptionResult {
        if task == .translate {
            throw TranscriptionEngineError.unsupportedTask("Apple Speech does not support translation")
        }

        let rec = recognizerForLanguage(language)
        guard rec.isAvailable else {
            throw TranscriptionEngineError.transcriptionFailed("Speech recognizer not available")
        }

        let buffer = try createAudioBuffer(from: audioSamples)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.append(buffer)
        request.endAudio()

        let startTime = CFAbsoluteTimeGetCurrent()
        let audioDuration = Double(audioSamples.count) / 16000.0

        let extracted: ExtractedResult = try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            var recognitionTask: SFSpeechRecognitionTask?

            // Timeout after 30s
            let timeoutWork = DispatchWorkItem { [weak rec] in
                guard !resumed else { return }
                resumed = true
                recognitionTask?.cancel()
                _ = rec // prevent premature release
                continuation.resume(throwing: TranscriptionEngineError.transcriptionFailed("Recognition timed out"))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeoutWork)

            recognitionTask = rec.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let error {
                    resumed = true
                    timeoutWork.cancel()
                    continuation.resume(throwing: TranscriptionEngineError.transcriptionFailed(error.localizedDescription))
                } else if let result, result.isFinal {
                    resumed = true
                    timeoutWork.cancel()
                    continuation.resume(returning: ExtractedResult(from: result))
                }
            }
        }

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let detectedLanguage = language ?? rec.locale.language.languageCode?.identifier

        return TranscriptionResult(
            text: extracted.text,
            detectedLanguage: detectedLanguage,
            duration: audioDuration,
            processingTime: processingTime,
            engineUsed: .appleSpeech,
            segments: extracted.segments
        )
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        onProgress: @Sendable @escaping (String) -> Bool
    ) async throws -> TranscriptionResult {
        if task == .translate {
            throw TranscriptionEngineError.unsupportedTask("Apple Speech does not support translation")
        }

        let rec = recognizerForLanguage(language)
        guard rec.isAvailable else {
            throw TranscriptionEngineError.transcriptionFailed("Speech recognizer not available")
        }

        let buffer = try createAudioBuffer(from: audioSamples)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.append(buffer)
        request.endAudio()

        let startTime = CFAbsoluteTimeGetCurrent()
        let audioDuration = Double(audioSamples.count) / 16000.0

        let extracted: ExtractedResult = try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            var lastExtracted: ExtractedResult?
            var recognitionTask: SFSpeechRecognitionTask?

            // Timeout after 30s — return last partial result if available
            let timeoutWork = DispatchWorkItem { [weak rec] in
                guard !resumed else { return }
                resumed = true
                recognitionTask?.cancel()
                _ = rec
                if let last = lastExtracted {
                    continuation.resume(returning: last)
                } else {
                    continuation.resume(throwing: TranscriptionEngineError.transcriptionFailed("Recognition timed out"))
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeoutWork)

            recognitionTask = rec.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let error {
                    resumed = true
                    timeoutWork.cancel()
                    // On error, return last partial result if available
                    if let last = lastExtracted {
                        continuation.resume(returning: last)
                    } else {
                        continuation.resume(throwing: TranscriptionEngineError.transcriptionFailed(error.localizedDescription))
                    }
                } else if let result {
                    let extracted = ExtractedResult(from: result)
                    lastExtracted = extracted
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        resumed = true
                        timeoutWork.cancel()
                        continuation.resume(returning: extracted)
                    } else {
                        let shouldContinue = onProgress(text)
                        if !shouldContinue {
                            resumed = true
                            timeoutWork.cancel()
                            continuation.resume(returning: extracted)
                        }
                    }
                }
            }
        }

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let detectedLanguage = language ?? rec.locale.language.languageCode?.identifier

        return TranscriptionResult(
            text: extracted.text,
            detectedLanguage: detectedLanguage,
            duration: audioDuration,
            processingTime: processingTime,
            engineUsed: .appleSpeech,
            segments: extracted.segments
        )
    }

    // MARK: - Private

    private struct ExtractedResult: Sendable {
        let text: String
        let segments: [TranscriptionSegment]

        init(from result: SFSpeechRecognitionResult) {
            self.text = result.bestTranscription.formattedString
            self.segments = result.bestTranscription.segments.map { seg in
                TranscriptionSegment(
                    text: seg.substring,
                    start: seg.timestamp,
                    end: seg.timestamp + seg.duration
                )
            }
        }
    }

    private func recognizerForLanguage(_ language: String?) -> SFSpeechRecognizer {
        if let language {
            return SFSpeechRecognizer(locale: Locale(identifier: language)) ?? SFSpeechRecognizer()!
        }
        return recognizer ?? SFSpeechRecognizer()!
    }

    private func createAudioBuffer(from samples: [Float]) throws -> AVAudioPCMBuffer {
        let sampleRate: Double = 16000
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else {
            throw TranscriptionEngineError.transcriptionFailed("Failed to create audio format")
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw TranscriptionEngineError.transcriptionFailed("Failed to create audio buffer")
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channelData = buffer.floatChannelData![0]
        samples.withUnsafeBufferPointer { src in
            channelData.update(from: src.baseAddress!, count: samples.count)
        }
        return buffer
    }
}
