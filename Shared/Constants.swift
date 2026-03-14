import Foundation

enum TypeWhisperConstants {
    static let appGroupIdentifier = "group.com.typewhisper.shared"
    static let keyboardBundleId = "com.typewhisper.typewhisper-app.keyboard"

    static let supportedAudioVideoExtensions: Set<String> = [
        "wav", "mp3", "m4a", "flac", "aac", "ogg", "wma",
        "mp4", "mov", "mkv", "avi"
    ]

    enum SharedFiles {
        static let keyboardHistoryFile = "keyboard_history.json"
        static let keyboardProfilesFile = "keyboard_profiles.json"
        static let keyboardStatusFile = "keyboard_status.json"
        static let pendingShareFile = "pending_share.json"
        static let sharedFilesDirectory = "shared_files"
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

        // Heartbeat
        static let flowHeartbeat = "flowHeartbeat"

        // Focus Mode keys
        static let focusRuntimeConfiguration = "focusRuntimeConfiguration"
        static let focusProfileMappings = "focusProfileMappings"
    }
}
