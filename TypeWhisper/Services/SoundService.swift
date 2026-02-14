import AVFoundation

enum SoundEvent {
    case recordingStarted
    case transcriptionSuccess
    case error

    var fileName: String {
        switch self {
        case .recordingStarted: return "recording_start"
        case .transcriptionSuccess: return "transcription_success"
        case .error: return "error"
        }
    }
}

@MainActor
class SoundService {
    private var players: [SoundEvent: AVAudioPlayer] = [:]

    init() {
        preloadSounds()
    }

    func play(_ event: SoundEvent, enabled: Bool) {
        guard enabled else { return }
        if let player = players[event] {
            player.currentTime = 0
            player.play()
        }
    }

    private func preloadSounds() {
        for event in [SoundEvent.recordingStarted, .transcriptionSuccess, .error] {
            if let url = Bundle.main.url(forResource: event.fileName, withExtension: "wav") {
                players[event] = try? AVAudioPlayer(contentsOf: url)
                players[event]?.prepareToPlay()
            }
        }
    }
}
