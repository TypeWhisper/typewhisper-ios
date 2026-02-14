import Foundation

/// Centralized localization for keyboard UI using String Catalog
enum L10n {
    static var start: String {
        String(localized: "start_button", bundle: .main)
    }

    static var stop: String {
        String(localized: "stop_button", bundle: .main)
    }

    static var recording: String {
        String(localized: "recording", bundle: .main)
    }

    static var transcribing: String {
        String(localized: "transcribing", bundle: .main)
    }

    static var noTextRecognized: String {
        String(localized: "no_text_recognized", bundle: .main)
    }

    static var tapToRetry: String {
        String(localized: "tap_to_retry", bundle: .main)
    }

    static var openApp: String {
        String(localized: "open_app", bundle: .main)
    }

    static var settingsLabel: String {
        String(localized: "settings_label", bundle: .main)
    }

    static var fullAccessRequired: String {
        String(localized: "full_access_required", bundle: .main)
    }

    static var noMicrophoneAccess: String {
        String(localized: "no_microphone_access", bundle: .main)
    }

    static var flowStarting: String {
        String(localized: "flow_starting", bundle: .main)
    }

    static var noTranscription: String {
        String(localized: "no_transcription", bundle: .main)
    }

    static var startCancelled: String {
        String(localized: "start_cancelled", bundle: .main)
    }

    static var flowSessionNotActive: String {
        String(localized: "flow_session_not_active", bundle: .main)
    }

    static var flowSessionCouldNotStart: String {
        String(localized: "flow_session_could_not_start", bundle: .main)
    }

    static var transcriptionProcessing: String {
        String(localized: "transcription_processing", bundle: .main)
    }
}
