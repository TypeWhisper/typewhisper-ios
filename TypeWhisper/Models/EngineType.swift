import Foundation

enum EngineType: String, CaseIterable, Identifiable, Codable {
    case whisper
    case appleSpeech
    case parakeet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whisper: "WhisperKit"
        case .appleSpeech: "Apple Speech"
        case .parakeet: "Parakeet"
        }
    }

    var supportsStreaming: Bool {
        switch self {
        case .whisper: true
        case .appleSpeech: true
        case .parakeet: false
        }
    }

    var supportsTranslation: Bool {
        switch self {
        case .whisper: true
        case .appleSpeech: false
        case .parakeet: false
        }
    }
}
