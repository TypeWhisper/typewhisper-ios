import Foundation

enum EngineType: String, CaseIterable, Identifiable, Codable {
    case whisper
    case appleSpeech

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whisper: "WhisperKit"
        case .appleSpeech: "Apple Speech"
        }
    }

    var supportsStreaming: Bool {
        switch self {
        case .whisper: true
        case .appleSpeech: true
        }
    }

    var supportsTranslation: Bool {
        switch self {
        case .whisper: true
        case .appleSpeech: false
        }
    }
}
