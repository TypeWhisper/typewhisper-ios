import Foundation

enum KeyboardConstants {
    static let appGroupIdentifier = TypeWhisperConstants.appGroupIdentifier

    enum SharedFiles {
        static let keyboardHistoryFile = TypeWhisperConstants.SharedFiles.keyboardHistoryFile
        static let keyboardProfilesFile = TypeWhisperConstants.SharedFiles.keyboardProfilesFile
    }

    enum SharedDefaults {
        static let lastTranscription = TypeWhisperConstants.SharedDefaults.lastTranscription
        static let selectedProfileId = TypeWhisperConstants.SharedDefaults.selectedProfileId
    }
}
