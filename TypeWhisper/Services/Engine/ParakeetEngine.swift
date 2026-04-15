import Foundation
import FluidAudio
import os

private let logger = Logger(subsystem: "com.typewhisper.typewhisper-app", category: "Parakeet")

final class ParakeetEngine: TranscriptionEngine, @unchecked Sendable {
    let engineType: EngineType = .parakeet
    let supportsStreaming = false
    let supportsTranslation = false

    private(set) var isModelLoaded = false
    private var asrManager: AsrManager?
    private var currentModelId: String?

    var onPhaseChange: ((String?) -> Void)?

    var supportedLanguages: [String] {
        ["bg", "hr", "cs", "da", "nl", "en", "et", "fi", "fr", "de",
         "el", "hu", "it", "lv", "lt", "mt", "pl", "pt", "ro", "sk",
         "sl", "es", "sv", "ru", "uk"]
    }

    func loadModel(_ model: ModelInfo, progress: @Sendable @escaping (Double, Double?) -> Void) async throws {
        guard model.engineType == .parakeet else {
            throw TranscriptionEngineError.modelLoadFailed("Not a Parakeet model")
        }

        if currentModelId != model.id {
            unloadModel()
        }

        do {
            progress(0.05, nil)
            onPhaseChange?("downloading")

            let models = try await AsrModels.downloadAndLoad(version: .v3)
            progress(0.60, nil)
            onPhaseChange?("loading")

            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            progress(0.90, nil)
            onPhaseChange?("prewarming")

            asrManager = manager
            currentModelId = model.id
            isModelLoaded = true
            progress(1.0, nil)
        } catch {
            isModelLoaded = false
            asrManager = nil
            currentModelId = nil
            throw TranscriptionEngineError.modelLoadFailed(error.localizedDescription)
        }
    }

    func unloadModel() {
        asrManager = nil
        currentModelId = nil
        isModelLoaded = false
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask
    ) async throws -> TranscriptionResult {
        guard let asrManager else {
            throw TranscriptionEngineError.modelNotLoaded
        }

        if task == .translate {
            throw TranscriptionEngineError.unsupportedTask("Parakeet does not support translation")
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let audioDuration = Double(audioSamples.count) / 16000.0

        logger.info("Transcribing \(audioSamples.count) samples (\(String(format: "%.1f", audioDuration))s audio), lang=\(language ?? "auto")")
        try await asrManager.resetDecoderState(for: .system)
        let result = try await asrManager.transcribe(audioSamples, source: .system)

        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("Parakeet done in \(String(format: "%.2f", processingTime))s: \(result.text.prefix(80))")

        var segments: [TranscriptionSegment] = []
        if let tokenTimings = result.tokenTimings, !tokenTimings.isEmpty {
            segments = Self.groupTokensIntoSegments(tokenTimings)
        }

        return TranscriptionResult(
            text: result.text,
            detectedLanguage: nil,
            duration: audioDuration,
            processingTime: processingTime,
            engineUsed: .parakeet,
            segments: segments
        )
    }

    // MARK: - Token-to-Segment Grouping

    private static func groupTokensIntoSegments(_ tokenTimings: [TokenTiming]) -> [TranscriptionSegment] {
        struct WordTiming {
            let word: String
            let start: Double
            let end: Double
        }

        var words: [WordTiming] = []
        var currentWord = ""
        var wordStart: Double = 0
        var wordEnd: Double = 0

        for timing in tokenTimings {
            let token = timing.token
            if token.isEmpty || token == "<blank>" || token == "<pad>" { continue }

            let startsNewWord = isWordBoundary(token) || currentWord.isEmpty

            if startsNewWord && !currentWord.isEmpty {
                let trimmed = currentWord.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    words.append(WordTiming(word: trimmed, start: wordStart, end: wordEnd))
                }
                currentWord = ""
            }

            if startsNewWord {
                currentWord = stripWordBoundaryPrefix(token)
                wordStart = timing.startTime
            } else {
                currentWord += token
            }
            wordEnd = timing.endTime
        }

        let lastTrimmed = currentWord.trimmingCharacters(in: .whitespaces)
        if !lastTrimmed.isEmpty {
            words.append(WordTiming(word: lastTrimmed, start: wordStart, end: wordEnd))
        }

        guard !words.isEmpty else { return [] }

        // Group words into sentence segments (split at sentence-ending punctuation or pause > 0.8s)
        let sentenceEndings: Set<Character> = [".", "?", "!"]
        let pauseThreshold: Double = 0.8

        var segments: [TranscriptionSegment] = []
        var segmentWords: [String] = []
        var segmentStart: Double = words[0].start
        var segmentEnd: Double = words[0].end

        for i in 0..<words.count {
            let word = words[i]
            segmentWords.append(word.word)
            segmentEnd = word.end

            let isSentenceEnd = word.word.last.map { sentenceEndings.contains($0) } ?? false
            let hasLongPause = i + 1 < words.count && (words[i + 1].start - word.end) > pauseThreshold
            let isLast = i == words.count - 1

            if isSentenceEnd || hasLongPause || isLast {
                let text = segmentWords.joined(separator: " ")
                segments.append(TranscriptionSegment(text: text, start: segmentStart, end: segmentEnd))
                segmentWords = []
                if i + 1 < words.count {
                    segmentStart = words[i + 1].start
                }
            }
        }

        return segments
    }
}
