import Foundation
import Speech

enum ModelStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double, bytesPerSecond: Double? = nil)
    case loading(phase: String? = nil)
    case ready
    case error(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

struct ModelInfo: Identifiable, Hashable {
    let id: String
    let engineType: EngineType
    let displayName: String
    let sizeDescription: String
    let estimatedSizeMB: Int
    let languageCount: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        lhs.id == rhs.id
    }

    var isRecommended: Bool {
        if engineType == .appleSpeech { return true }

        let ram = ProcessInfo.processInfo.physicalMemory
        let gb = ram / (1024 * 1024 * 1024)

        switch displayName {
        case "Tiny", "Base":
            return gb < 4
        case "Small":
            return gb >= 4 && gb <= 6
        case "Large v3 Turbo", "Distil Large v3":
            return gb >= 6
        default:
            return false
        }
    }
}

extension ModelInfo {
    static let whisperModels: [ModelInfo] = [
        ModelInfo(
            id: "openai_whisper-tiny",
            engineType: .whisper,
            displayName: "Tiny",
            sizeDescription: "~39 MB",
            estimatedSizeMB: 39,
            languageCount: 99
        ),
        ModelInfo(
            id: "openai_whisper-base",
            engineType: .whisper,
            displayName: "Base",
            sizeDescription: "~74 MB",
            estimatedSizeMB: 74,
            languageCount: 99
        ),
        ModelInfo(
            id: "openai_whisper-small",
            engineType: .whisper,
            displayName: "Small",
            sizeDescription: "~244 MB",
            estimatedSizeMB: 244,
            languageCount: 99
        ),
        ModelInfo(
            id: "openai_whisper-large-v3_turbo",
            engineType: .whisper,
            displayName: "Large v3 Turbo",
            sizeDescription: "~800 MB",
            estimatedSizeMB: 800,
            languageCount: 99
        ),
        ModelInfo(
            id: "distil-whisper_distil-large-v3",
            engineType: .whisper,
            displayName: "Distil Large v3",
            sizeDescription: "~594 MB",
            estimatedSizeMB: 594,
            languageCount: 99
        ),
    ]

    static let appleSpeechModels: [ModelInfo] = [
        ModelInfo(
            id: "apple-speech-ondevice",
            engineType: .appleSpeech,
            displayName: "Apple Speech",
            sizeDescription: "Built-in",
            estimatedSizeMB: 0,
            languageCount: SFSpeechRecognizer.supportedLocales().count
        ),
    ]

    static var allModels: [ModelInfo] {
        appleSpeechModels + whisperModels
    }

    static func models(for engine: EngineType) -> [ModelInfo] {
        switch engine {
        case .whisper: whisperModels
        case .appleSpeech: appleSpeechModels
        }
    }
}
