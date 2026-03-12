import Foundation
import os.log

private let logger = Logger(subsystem: "com.typewhisper.keyboard", category: "AudioService")

/// Keyboard audio service that communicates with the main app via shared UserDefaults.
/// The main app does the actual recording; this service just signals start/stop.
class KeyboardAudioService {
    private let sharedDefaults = UserDefaults(suiteName: TypeWhisperConstants.appGroupIdentifier)

    private var pollingTimer: Timer?

    init() {
        logger.info("KeyboardAudioService init: sharedDefaults=\(sharedDefaults != nil ? "OK" : "NIL")")
    }

    /// Diagnostic info about App Group and Flow Session state
    var diagnosticInfo: String {
        var parts: [String] = []

        if sharedDefaults == nil {
            parts.append("UD=nil")
        } else {
            parts.append("UD=ok")
        }

        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: TypeWhisperConstants.appGroupIdentifier
        )
        if containerURL == nil {
            parts.append("container=nil")
        } else {
            parts.append("container=ok")
        }

        if let expires = sharedDefaults?.object(forKey: TypeWhisperConstants.SharedDefaults.flowSessionExpires) as? Date {
            let remaining = expires.timeIntervalSinceNow
            parts.append("exp=\(Int(remaining))s")
        } else {
            parts.append("exp=nil")
        }

        if let heartbeat = sharedDefaults?.object(forKey: TypeWhisperConstants.SharedDefaults.flowHeartbeat) as? Date {
            let staleness = Date().timeIntervalSince(heartbeat)
            parts.append("hb=\(String(format: "%.1f", staleness))s")
        } else {
            parts.append("hb=nil")
        }

        let active = sharedDefaults?.bool(forKey: TypeWhisperConstants.SharedDefaults.flowSessionActive) ?? false
        parts.append("active=\(active)")

        return parts.joined(separator: " | ")
    }

    /// Check if a Flow Session is currently active AND the main app is alive
    var isFlowSessionActive: Bool {
        guard let expires = sharedDefaults?.object(forKey: TypeWhisperConstants.SharedDefaults.flowSessionExpires) as? Date,
              expires > Date() else {
            logger.info("isFlowSessionActive=false reason=no_expires diag=[\(self.diagnosticInfo)]")
            return false
        }

        // Check heartbeat - main app writes Date() every 1s during active session
        guard let heartbeat = sharedDefaults?.object(forKey: TypeWhisperConstants.SharedDefaults.flowHeartbeat) as? Date else {
            logger.info("isFlowSessionActive=false reason=no_heartbeat diag=[\(self.diagnosticInfo)]")
            return false
        }
        let staleness = Date().timeIntervalSince(heartbeat)
        if staleness > 3.0 {
            logger.warning("Flow heartbeat stale by \(String(format: "%.1f", staleness))s - main app likely killed")
            return false
        }

        return true
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
        guard isFlowSessionActive else {
            return "Start Flow"
        }

        pollingTimer?.invalidate()
        pollingTimer = nil

        sharedDefaults?.set(language, forKey: TypeWhisperConstants.SharedDefaults.transcriptionLanguage)
        sharedDefaults?.set("recording", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
        sharedDefaults?.synchronize()

        return nil
    }

    /// Signal the main app to stop recording and wait for transcription
    func stopRecording(completion: @escaping (String?, String?) -> Void) {
        sharedDefaults?.set("stopped", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
        sharedDefaults?.synchronize()

        pollForResult(completion: completion)
    }

    private func pollForResult(completion: @escaping (String?, String?) -> Void) {
        let maxAttempts = 300
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
                self.pollingTimer = nil
                self.sharedDefaults?.removeObject(forKey: TypeWhisperConstants.SharedDefaults.transcriptionResult)
                self.sharedDefaults?.synchronize()
                completion(result, nil)
                return
            }

            if let error = self.sharedDefaults?.string(forKey: TypeWhisperConstants.SharedDefaults.transcriptionError), !error.isEmpty {
                timer.invalidate()
                self.pollingTimer = nil
                self.sharedDefaults?.removeObject(forKey: TypeWhisperConstants.SharedDefaults.transcriptionError)
                self.sharedDefaults?.synchronize()
                completion(nil, error)
                return
            }

            let state = self.sharedDefaults?.string(forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState) ?? "idle"
            if state == "idle" && attempts > 10 {
                timer.invalidate()
                self.pollingTimer = nil
                completion(nil, nil)
                return
            }

            if attempts >= maxAttempts {
                timer.invalidate()
                self.pollingTimer = nil
                completion(nil, "Timeout")
            }
        }
    }

    /// Cancel any ongoing recording
    func cancelRecording() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        sharedDefaults?.set("aborted", forKey: TypeWhisperConstants.SharedDefaults.keyboardRecordingState)
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
