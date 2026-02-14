import Foundation
import Combine
import UIKit

@MainActor
final class RecordingViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: RecordingViewModel?
    static var shared: RecordingViewModel {
        guard let instance = _shared else {
            fatalError("RecordingViewModel not initialized")
        }
        return instance
    }

    enum State: Equatable {
        case idle
        case recording
        case processing
        case done(String)
        case error(String)
    }

    @Published var state: State = .idle
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var partialText: String = ""
    @Published var isStreaming: Bool = false
    @Published var lastResult: String = ""
    @Published var whisperModeEnabled: Bool {
        didSet { UserDefaults.standard.set(whisperModeEnabled, forKey: "whisperModeEnabled") }
    }
    @Published var soundFeedbackEnabled: Bool {
        didSet { UserDefaults.standard.set(soundFeedbackEnabled, forKey: "soundFeedbackEnabled") }
    }
    @Published var selectedProfile: Profile?

    private let audioRecordingService: AudioRecordingService
    private let modelManager: ModelManagerService
    private let settingsViewModel: SettingsViewModel
    private let historyService: HistoryService
    private let profileService: ProfileService
    private let translationService: TranslationService
    private let dictionaryService: DictionaryService
    private let snippetService: SnippetService
    private let soundService: SoundService

    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var streamingTask: Task<Void, Never>?
    private var silenceCancellable: AnyCancellable?

    init(
        audioRecordingService: AudioRecordingService,
        modelManager: ModelManagerService,
        settingsViewModel: SettingsViewModel,
        historyService: HistoryService,
        profileService: ProfileService,
        translationService: TranslationService,
        dictionaryService: DictionaryService,
        snippetService: SnippetService,
        soundService: SoundService
    ) {
        self.audioRecordingService = audioRecordingService
        self.modelManager = modelManager
        self.settingsViewModel = settingsViewModel
        self.historyService = historyService
        self.profileService = profileService
        self.translationService = translationService
        self.dictionaryService = dictionaryService
        self.snippetService = snippetService
        self.soundService = soundService
        self.whisperModeEnabled = UserDefaults.standard.bool(forKey: "whisperModeEnabled")
        self.soundFeedbackEnabled = UserDefaults.standard.object(forKey: "soundFeedbackEnabled") as? Bool ?? true

        setupBindings()
    }

    var canRecord: Bool {
        modelManager.activeEngine?.isModelLoaded == true
    }

    var needsMicPermission: Bool {
        !audioRecordingService.hasMicrophonePermission
    }

    private func setupBindings() {
        audioRecordingService.$audioLevel
            .dropFirst()
            .sink { [weak self] level in
                DispatchQueue.main.async {
                    self?.audioLevel = level
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    func startRecording() {
        guard canRecord else {
            showError("No model loaded. Please download a model first.")
            return
        }

        guard audioRecordingService.hasMicrophonePermission else {
            showError("Microphone permission required.")
            return
        }

        let effectiveWhisperMode = selectedProfile?.whisperModeOverride ?? whisperModeEnabled
        audioRecordingService.gainMultiplier = effectiveWhisperMode ? 4.0 : 1.0

        do {
            try audioRecordingService.startRecording()
            state = .recording
            soundService.play(.recordingStarted, enabled: soundFeedbackEnabled)
            partialText = ""
            lastResult = ""
            recordingStartTime = Date()
            startRecordingTimer()
            startStreamingIfSupported()
            startSilenceDetection()
        } catch {
            soundService.play(.error, enabled: soundFeedbackEnabled)
            showError(error.localizedDescription)
        }
    }

    func stopRecording() {
        guard state == .recording else { return }

        stopStreaming()
        stopSilenceDetection()
        stopRecordingTimer()
        let samples = audioRecordingService.stopRecording()

        guard !samples.isEmpty else {
            state = .idle
            partialText = ""
            return
        }

        let audioDuration = Double(samples.count) / 16000.0
        guard audioDuration >= 0.3 else {
            state = .idle
            partialText = ""
            return
        }

        let language = effectiveLanguage
        let task = effectiveTask
        let translationTarget = effectiveTranslationTarget

        state = .processing

        Task {
            do {
                let result = try await modelManager.transcribe(
                    audioSamples: samples,
                    language: language,
                    task: task
                )

                var text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    state = .idle
                    partialText = ""
                    return
                }

                if let targetCode = translationTarget {
                    let target = Locale.Language(identifier: targetCode)
                    let source = (result.detectedLanguage ?? language).map { Locale.Language(identifier: $0) }
                    text = try await translationService.translate(text: text, from: source, to: target)
                }

                // Post-processing pipeline
                text = snippetService.applySnippets(to: text)
                text = dictionaryService.applyCorrections(to: text)

                partialText = ""
                lastResult = text

                // Copy to clipboard
                UIPasteboard.general.string = text

                historyService.addRecord(
                    rawText: result.text,
                    finalText: text,
                    durationSeconds: audioDuration,
                    language: language,
                    engineUsed: result.engineUsed.rawValue
                )

                soundService.play(.transcriptionSuccess, enabled: soundFeedbackEnabled)
                state = .done(text)
            } catch {
                soundService.play(.error, enabled: soundFeedbackEnabled)
                showError(error.localizedDescription)
            }
        }
    }

    func toggleRecording() {
        if state == .recording {
            stopRecording()
        } else if state == .idle || state == .done("") || isDoneState {
            startRecording()
        }
    }

    private var isDoneState: Bool {
        if case .done = state { return true }
        return false
    }

    func requestMicPermission() {
        Task {
            _ = await audioRecordingService.requestMicrophonePermission()
            objectWillChange.send()
        }
    }

    func dismissResult() {
        state = .idle
        lastResult = ""
    }

    // MARK: - Effective Settings

    private var effectiveLanguage: String? {
        if let profileLang = selectedProfile?.inputLanguage {
            return profileLang == "auto" ? nil : profileLang
        }
        return settingsViewModel.selectedLanguage
    }

    private var effectiveTask: TranscriptionTask {
        .transcribe
    }

    private var effectiveTranslationTarget: String? {
        if let profileTarget = selectedProfile?.translationTargetLanguage {
            return profileTarget
        }
        if settingsViewModel.translationEnabled {
            return settingsViewModel.translationTargetLanguage
        }
        return nil
    }

    // MARK: - Streaming

    private var confirmedStreamingText = ""

    private func startStreamingIfSupported() {
        guard let engine = modelManager.activeEngine, engine.supportsStreaming else { return }

        isStreaming = true
        confirmedStreamingText = ""
        let streamLanguage = effectiveLanguage
        let streamTask = effectiveTask
        streamingTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(1.5))

            while !Task.isCancelled, self.state == .recording {
                let buffer = self.audioRecordingService.getCurrentBuffer()
                let bufferDuration = Double(buffer.count) / 16000.0

                if bufferDuration > 0.5 {
                    do {
                        let confirmed = self.confirmedStreamingText
                        let result = try await self.modelManager.transcribe(
                            audioSamples: buffer,
                            language: streamLanguage,
                            task: streamTask,
                            onProgress: { [weak self] text in
                                guard let self, !Task.isCancelled else { return false }
                                let stable = Self.stabilizeText(confirmed: confirmed, new: text)
                                DispatchQueue.main.async {
                                    self.partialText = stable
                                }
                                return true
                            }
                        )
                        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            let stable = Self.stabilizeText(confirmed: confirmed, new: text)
                            self.partialText = stable
                            self.confirmedStreamingText = stable
                        }
                    } catch {
                        // Streaming errors are non-fatal
                    }
                }

                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    private func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        confirmedStreamingText = ""
    }

    nonisolated private static func stabilizeText(confirmed: String, new: String) -> String {
        let new = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !confirmed.isEmpty else { return new }
        guard !new.isEmpty else { return confirmed }

        if new.hasPrefix(confirmed) { return new }

        let confirmedChars = Array(confirmed.unicodeScalars)
        let newChars = Array(new.unicodeScalars)
        var matchEnd = 0
        for i in 0..<min(confirmedChars.count, newChars.count) {
            if confirmedChars[i] == newChars[i] {
                matchEnd = i + 1
            } else {
                break
            }
        }

        if matchEnd > confirmed.count / 2 {
            let newContent = String(new.unicodeScalars.dropFirst(matchEnd))
            return confirmed + newContent
        }

        return confirmed
    }

    // MARK: - Silence Detection

    private func startSilenceDetection() {
        guard audioRecordingService.silenceAutoStopDuration > 0 else { return }
        silenceCancellable = audioRecordingService.$silenceDuration
            .dropFirst()
            .sink { [weak self] duration in
                DispatchQueue.main.async {
                    guard let self, self.state == .recording else { return }
                    if duration >= self.audioRecordingService.silenceAutoStopDuration {
                        self.audioRecordingService.didAutoStop = true
                        self.stopRecording()
                    }
                }
            }
    }

    private func stopSilenceDetection() {
        silenceCancellable?.cancel()
        silenceCancellable = nil
    }

    // MARK: - Timer

    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }

    private func showError(_ message: String) {
        state = .error(message)
        Task {
            try? await Task.sleep(for: .seconds(3))
            if case .error = state {
                state = .idle
            }
        }
    }
}
