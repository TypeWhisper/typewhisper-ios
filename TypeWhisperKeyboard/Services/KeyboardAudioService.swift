import Foundation
import os.log

private let logger = Logger(subsystem: "com.typewhisper.keyboard", category: "AudioService")

/// Keyboard audio service that communicates with the main app via shared UserDefaults.
/// The main app does the actual recording; this service just signals start/stop.
class KeyboardAudioService {
    private let sharedDefaults = UserDefaults(suiteName: TypeWhisperConstants.appGroupIdentifier)

    private var pollingTimer: Timer?

    init() {}

    /// Check if a Flow Session is currently active
    var isFlowSessionActive: Bool {
        guard let expires = sharedDefaults?.object(forKey: TypeWhisperConstants.SharedDefaults.flowSessionExpires) as? Date else {
            return false
        }
        return expires > Date()
    }

    /// Signal the main app to start recording
    func startRecording() -> String? {
        var language = sharedDefaults?.string(forKey: "language") ?? "auto"
        if language == "auto" {
            language = Locale.current.language.languageCode.flatMap { lang in
                Locale.current.language.region.map { region in
                    "\(lang.identifier)-\(region.identifier)"
                }
            } ?? "auto"
        }
        logger.info("startRecording called with language: \(language)")

        guard isFlowSessionActive else {
            logger.warning("No Flow Session active")
            return "Start Flow"
        }

        sharedDefaults?.set(language, forKey: TypeWhisperConstants.SharedDefaults.transcriptionLanguage)
        sharedDefaults?.set("recording", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
        sharedDefaults?.synchronize()

        logger.info("Signaled main app: recording started")
        return nil
    }

    /// Signal the main app to stop recording and wait for transcription
    func stopRecording(completion: @escaping (String?, String?) -> Void) {
        logger.info("stopRecording called")

        sharedDefaults?.set("stopped", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
        sharedDefaults?.synchronize()

        pollForResult(completion: completion)
    }

    private func pollForResult(completion: @escaping (String?, String?) -> Void) {
        let maxAttempts = 100
        let counter = PollCounter()

        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            counter.value += 1
            let attempts = counter.value

            if let result = self.sharedDefaults?.string(forKey: TypeWhisperConstants.SharedDefaults.transcriptionResult), !result.isEmpty {
                timer.invalidate()
                self.sharedDefaults?.removeObject(forKey: TypeWhisperConstants.SharedDefaults.transcriptionResult)
                self.sharedDefaults?.synchronize()
                completion(result, nil)
                return
            }

            if let error = self.sharedDefaults?.string(forKey: TypeWhisperConstants.SharedDefaults.transcriptionError), !error.isEmpty {
                timer.invalidate()
                self.sharedDefaults?.removeObject(forKey: TypeWhisperConstants.SharedDefaults.transcriptionError)
                self.sharedDefaults?.synchronize()
                completion(nil, error)
                return
            }

            let state = self.sharedDefaults?.string(forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState) ?? "idle"
            if state == "idle" && attempts > 10 {
                timer.invalidate()
                completion(nil, nil)
                return
            }

            if attempts >= maxAttempts {
                timer.invalidate()
                completion(nil, "Timeout")
            }
        }
    }

    /// Cancel any ongoing recording
    func cancelRecording() {
        pollingTimer?.invalidate()
        sharedDefaults?.set("idle", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
        sharedDefaults?.synchronize()
    }

    private class PollCounter: @unchecked Sendable {
        var value = 0
    }

    /// Get real audio levels from main app for visualization
    func getAudioLevels() -> [Float] {
        sharedDefaults?.synchronize()

        if let levels = sharedDefaults?.array(forKey: TypeWhisperConstants.SharedDefaults.audioLevels) as? [Double], !levels.isEmpty {
            return levels.map { Float($0) }
        }
        if let levels = sharedDefaults?.array(forKey: TypeWhisperConstants.SharedDefaults.audioLevels) as? [NSNumber], !levels.isEmpty {
            return levels.map { $0.floatValue }
        }
        return Array(repeating: 0, count: 24)
    }
}
