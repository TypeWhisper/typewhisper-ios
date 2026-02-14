import Foundation

enum TypeWhisperConstants {
    static let appGroupIdentifier = "group.com.typewhisper.shared"

    enum SharedFiles {
        static let keyboardHistoryFile = "keyboard_history.json"
        static let keyboardProfilesFile = "keyboard_profiles.json"
    }

    enum SharedDefaults {
        static let lastTranscription = "lastTranscription"
        static let keyboardHasFullAccess = "keyboard_has_full_access"
        static let keyboardLastCheckedAt = "keyboard_last_checked_at"

        // Flow Session keys
        static let flowSessionActive = "flowSessionActive"
        static let flowSessionExpires = "flowSessionExpires"
        static let keyboardRecordingState = "keyboardRecordingState"
        static let transcriptionLanguage = "transcriptionLanguage"
        static let transcriptionResult = "transcriptionResult"
        static let transcriptionError = "transcriptionError"
        static let audioLevels = "audioLevels"
        static let selectedProfileId = "selectedProfileId"
    }
}
