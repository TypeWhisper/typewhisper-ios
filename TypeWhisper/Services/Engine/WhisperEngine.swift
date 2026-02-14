import Foundation
import WhisperKit

final class WhisperEngine: TranscriptionEngine, @unchecked Sendable {
    let engineType: EngineType = .whisper
    let supportsStreaming = true
    let supportsTranslation = true

    private(set) var isModelLoaded = false
    private var whisperKit: WhisperKit?
    private var currentModelId: String?

    var supportedLanguages: [String] {
        [
            "af", "am", "ar", "as", "az", "ba", "be", "bg", "bn", "bo",
            "br", "bs", "ca", "cs", "cy", "da", "de", "el", "en", "es",
            "et", "eu", "fa", "fi", "fo", "fr", "gl", "gu", "ha", "haw",
            "he", "hi", "hr", "ht", "hu", "hy", "id", "is", "it", "ja",
            "jw", "ka", "kk", "km", "kn", "ko", "la", "lb", "ln", "lo",
            "lt", "lv", "mg", "mi", "mk", "ml", "mn", "mr", "ms", "mt",
            "my", "ne", "nl", "nn", "no", "oc", "pa", "pl", "ps", "pt",
            "ro", "ru", "sa", "sd", "si", "sk", "sl", "sn", "so", "sq",
            "sr", "su", "sv", "sw", "ta", "te", "tg", "th", "tk", "tl",
            "tr", "tt", "uk", "ur", "uz", "vi", "vo", "yi", "yo", "yue",
            "zh",
        ]
    }

    var onPhaseChange: ((String?) -> Void)?

    func loadModel(_ model: ModelInfo, progress: @Sendable @escaping (Double, Double?) -> Void) async throws {
        guard model.engineType == .whisper else {
            throw TranscriptionEngineError.modelLoadFailed("Not a Whisper model")
        }

        if currentModelId != model.id {
            unloadModel()
        }

        do {
            progress(0.05, nil)

            var lastReportedProgress = 0.0
            let modelFolder = try await WhisperKit.download(variant: model.id) { downloadProgress in
                let fraction = downloadProgress.fractionCompleted
                let mapped = 0.05 + fraction * 0.75
                guard mapped - lastReportedProgress >= 0.01 else { return }
                lastReportedProgress = mapped
                let speed = downloadProgress.userInfo[.throughputKey] as? Double
                progress(mapped, speed)
            }

            progress(0.80, nil)
            let config = WhisperKitConfig(
                modelFolder: modelFolder.path,
                verbose: false,
                logLevel: .error,
                prewarm: false,
                load: false,
                download: false
            )

            let kit = try await WhisperKit(config)

            kit.modelStateCallback = { [weak self] _, newState in
                switch newState {
                case .loading:
                    self?.onPhaseChange?("loading")
                case .prewarming:
                    self?.onPhaseChange?("prewarming")
                default:
                    break
                }
            }

            try await kit.loadModels()
            progress(0.90, nil)
            try await kit.prewarmModels()

            whisperKit = kit
            progress(1.0, nil)

            currentModelId = model.id
            isModelLoaded = true
        } catch {
            isModelLoaded = false
            whisperKit = nil
            currentModelId = nil
            throw TranscriptionEngineError.modelLoadFailed(error.localizedDescription)
        }
    }

    func unloadModel() {
        whisperKit = nil
        currentModelId = nil
        isModelLoaded = false
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask
    ) async throws -> TranscriptionResult {
        guard let whisperKit else {
            throw TranscriptionEngineError.modelNotLoaded
        }

        let whisperTask: DecodingTask = task == .translate ? .translate : .transcribe

        let options = DecodingOptions(
            verbose: false,
            task: whisperTask,
            language: language,
            temperature: 0.0,
            temperatureFallbackCount: 3,
            usePrefillPrompt: true,
            usePrefillCache: true,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            chunkingStrategy: .vad
        )

        let startTime = CFAbsoluteTimeGetCurrent()

        let results = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: options
        )

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let audioDuration = Double(audioSamples.count) / 16000.0

        let fullText = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let detectedLanguage = results.first?.language

        var segments: [TranscriptionSegment] = []
        for wkResult in results {
            for seg in wkResult.segments {
                let segText = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !segText.isEmpty else { continue }
                segments.append(TranscriptionSegment(text: segText, start: TimeInterval(seg.start), end: TimeInterval(seg.end)))
            }
        }

        return TranscriptionResult(
            text: fullText,
            detectedLanguage: detectedLanguage,
            duration: audioDuration,
            processingTime: processingTime,
            engineUsed: .whisper,
            segments: segments
        )
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        onProgress: @Sendable @escaping (String) -> Bool
    ) async throws -> TranscriptionResult {
        guard let whisperKit else {
            throw TranscriptionEngineError.modelNotLoaded
        }

        let whisperTask: DecodingTask = task == .translate ? .translate : .transcribe

        let options = DecodingOptions(
            verbose: false,
            task: whisperTask,
            language: language,
            temperature: 0.0,
            temperatureFallbackCount: 3,
            usePrefillPrompt: true,
            usePrefillCache: true,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            chunkingStrategy: .vad
        )

        let startTime = CFAbsoluteTimeGetCurrent()

        let results = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: options,
            callback: { progress in
                let shouldContinue = onProgress(progress.text)
                return shouldContinue ? nil : false
            }
        )

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        let audioDuration = Double(audioSamples.count) / 16000.0

        let fullText = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let detectedLanguage = results.first?.language

        var segments: [TranscriptionSegment] = []
        for wkResult in results {
            for seg in wkResult.segments {
                let segText = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !segText.isEmpty else { continue }
                segments.append(TranscriptionSegment(text: segText, start: TimeInterval(seg.start), end: TimeInterval(seg.end)))
            }
        }

        return TranscriptionResult(
            text: fullText,
            detectedLanguage: detectedLanguage,
            duration: audioDuration,
            processingTime: processingTime,
            engineUsed: .whisper,
            segments: segments
        )
    }
}
