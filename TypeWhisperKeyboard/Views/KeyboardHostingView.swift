import SwiftUI
import UIKit
import os.log
import Translation

private let logger = Logger(subsystem: "com.typewhisper.keyboard", category: "ViewModel")

struct KeyboardHostingView: View {
    weak var inputViewController: UIInputViewController?
    let textDocumentProxy: UITextDocumentProxy

    @StateObject private var viewModel = KeyboardViewModel()

    var body: some View {
        GeometryReader { geometry in
            let metrics = KeyboardMetrics.resolve(for: geometry.size)
            let theme = KeyboardTheme.default

            MainKeyboardView(
                viewModel: viewModel,
                textDocumentProxy: textDocumentProxy,
                hasFullAccessProvider: { inputViewController?.hasFullAccess ?? false },
                onSwitchKeyboard: {
                    inputViewController?.advanceToNextInputMode()
                },
                onOpenApp: {
                    viewModel.openMainApp()
                },
                metrics: metrics,
                theme: theme
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .translationTask(viewModel.translationConfig) { session in
                await viewModel.handleTranslation(session)
            }
            .onAppear {
                viewModel.insertTextHandler = { text in
                    textDocumentProxy.insertText(text)
                }
                viewModel.openURLHandler = { [weak inputViewController] url in
                    var responder: UIResponder? = inputViewController
                    while let r = responder {
                        if let app = r as? UIApplication {
                            app.open(url, options: [:], completionHandler: nil)
                            return
                        }
                        responder = r.next
                    }
                }
                viewModel.loadProfiles()
                viewModel.refreshFlowStatus()
            }
        }
    }
}

@MainActor
class KeyboardViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var isPendingStart = false
    @Published var isFlowSessionActive = false
    @Published var error: String?
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 24)
    @Published var shiftEnabled = false
    @Published var bannerMessage: String?
    @Published var bannerActionTitle: String = L10n.openApp
    @Published var bannerOpensSettings = false
    @Published var availableProfiles: [KeyboardProfileDTO] = []
    @Published var selectedProfileId: UUID?
    @Published var translationConfig: TranslationSession.Configuration?
    private var pendingTranslationText: String?

    private var audioService: KeyboardAudioService?
    private var levelUpdateTimer: Timer?
    private var recordingTimer: Timer?
    private var flowStatusTimer: Timer?
    private var flowStartDeadline: Date?
    private var isHoldRecording = false
    private var currentLanguage: String = "auto"
    private let maxDuration: TimeInterval = 60
    var insertTextHandler: ((String) -> Void)?
    var openURLHandler: ((URL) -> Void)?

    func toggleShift() {
        shiftEnabled.toggle()
    }

    func displayLetter(for label: String) -> String {
        shiftEnabled ? label.uppercased() : label.lowercased()
    }

    func handleLetterTap(_ label: String) -> String {
        let output = displayLetter(for: label)
        if shiftEnabled {
            shiftEnabled = false
        }
        return output
    }

    func handleSpaceTap() {
        error = nil
    }

    func loadProfiles() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: KeyboardConstants.appGroupIdentifier
        ) else { return }

        let fileURL = groupURL.appending(path: KeyboardConstants.SharedFiles.keyboardProfilesFile)
        guard let data = try? Data(contentsOf: fileURL),
              let profiles = try? JSONDecoder().decode([KeyboardProfileDTO].self, from: data) else {
            availableProfiles = []
            return
        }

        availableProfiles = profiles

        let defaults = UserDefaults(suiteName: KeyboardConstants.appGroupIdentifier)
        if let savedId = defaults?.string(forKey: KeyboardConstants.SharedDefaults.selectedProfileId),
           let uuid = UUID(uuidString: savedId),
           profiles.contains(where: { $0.id == uuid }) {
            selectedProfileId = uuid
        } else {
            selectedProfileId = nil
        }

        // Only apply language if a profile is actively selected
        if let profileId = selectedProfileId,
           let profile = availableProfiles.first(where: { $0.id == profileId }),
           let lang = profile.inputLanguage {
            let defaults = UserDefaults(suiteName: KeyboardConstants.appGroupIdentifier)
            defaults?.set(lang, forKey: "language")
            currentLanguage = lang
        } else {
            currentLanguage = readTranscriptionLanguage()
        }
    }

    func selectProfile(_ profile: KeyboardProfileDTO) {
        if selectedProfileId == profile.id {
            deselectProfile()
            return
        }
        selectedProfileId = profile.id
        let defaults = UserDefaults(suiteName: KeyboardConstants.appGroupIdentifier)
        defaults?.set(profile.id.uuidString, forKey: KeyboardConstants.SharedDefaults.selectedProfileId)
        if let lang = profile.inputLanguage {
            defaults?.set(lang, forKey: "language")
            currentLanguage = lang
        }
    }

    func deselectProfile() {
        selectedProfileId = nil
        let defaults = UserDefaults(suiteName: KeyboardConstants.appGroupIdentifier)
        defaults?.removeObject(forKey: KeyboardConstants.SharedDefaults.selectedProfileId)
        defaults?.removeObject(forKey: "language")
        currentLanguage = "auto"
    }

    private func readTranscriptionLanguage() -> String {
        UserDefaults(suiteName: KeyboardConstants.appGroupIdentifier)?
            .string(forKey: "language") ?? "auto"
    }

    func toggleRecording(hasFullAccess: Bool) {
        if isRecording {
            stopRecording()
        } else if isPendingStart {
            cancelPendingStart()
        } else {
            startRecording(hasFullAccess: hasFullAccess)
        }
    }

    func handleMicTap(hasFullAccess: Bool) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        toggleRecording(hasFullAccess: hasFullAccess)
    }

    func handleMicHoldStart(hasFullAccess: Bool) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        guard !isRecording, !isPendingStart else { return }
        isHoldRecording = true
        startRecording(hasFullAccess: hasFullAccess)
    }

    func handleMicHoldEnd() {
        guard isHoldRecording, isRecording else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        isHoldRecording = false
        stopRecording()
    }

    func startRecording(hasFullAccess: Bool) {
        guard !isRecording, !isProcessing else { return }

        error = nil
        bannerMessage = nil
        currentLanguage = readTranscriptionLanguage()
        isPendingStart = false

        if !hasFullAccess {
            triggerFlowFallback(message: L10n.fullAccessRequired, opensSettings: true)
            return
        }

        audioService = audioService ?? KeyboardAudioService()
        refreshFlowStatus()

        if isFlowSessionActive {
            startFlowRecording()
        } else {
            beginFlowStart(autoOpen: true, message: L10n.flowStarting, startPolling: true)
        }
    }

    func stopRecording() {
        if isPendingStart && !isRecording {
            cancelPendingStart()
            return
        }
        guard isRecording else { return }

        stopMaxDurationTimer()
        stopLevelPolling()
        isRecording = false
        isProcessing = true

        guard let service = audioService else {
            isProcessing = false
            return
        }

        service.stopRecording { [weak self] result, errorMsg in
            Task { @MainActor in
                guard let self = self else { return }
                self.isProcessing = false
                self.audioLevels = Array(repeating: 0, count: 24)

                if let text = result, !text.isEmpty {
                    self.handleTranscriptionResult(text)
                } else {
                    self.error = errorMsg ?? L10n.noTranscription
                    self.bannerMessage = self.error
                }
            }
        }
    }

    func cancelRecording() {
        stopMaxDurationTimer()
        stopLevelPolling()
        isHoldRecording = false
        isRecording = false
        isProcessing = false
        isPendingStart = false
        stopFlowStatusTimer()
        audioService?.cancelRecording()
        audioLevels = Array(repeating: 0, count: 24)
    }

    func openMainApp() {
        if bannerOpensSettings {
            let keyboardSettingsURL = URL(string: "App-Prefs:root=General&path=Keyboard")
            let appSettingsURL = URL(string: "app-settings:")
            if let url = keyboardSettingsURL ?? appSettingsURL {
                openURLHandler?(url)
            }
            return
        }

        if let url = URL(string: "typewhisper://startflow?duration=300") {
            openURLHandler?(url)
        }
        if isPendingStart {
            flowStartDeadline = Date().addingTimeInterval(10)
        }
        startFlowStatusTimer()
    }

    private func startFlowRecording() {
        audioService = audioService ?? KeyboardAudioService()
        guard let service = audioService else { return }

        if let errorMsg = service.startRecording() {
            logger.warning("Flow recording start failed: \(errorMsg)")
            triggerFlowFallback(message: L10n.flowSessionCouldNotStart)
            return
        }

        isRecording = true
        bannerMessage = nil
        isFlowSessionActive = true
        isPendingStart = false
        stopFlowStatusTimer()
        startFlowLevelPolling()
        startMaxDurationTimer()
    }

    private func beginFlowStart(autoOpen: Bool, message: String, startPolling: Bool) {
        isHoldRecording = false
        isRecording = false
        isProcessing = false
        isPendingStart = true
        bannerMessage = message
        bannerActionTitle = L10n.openApp
        bannerOpensSettings = false
        flowStartDeadline = startPolling ? Date().addingTimeInterval(10) : nil
        if startPolling {
            startFlowStatusTimer()
        }

        if autoOpen {
            if let url = URL(string: "typewhisper://startflow?duration=300") {
                openURLHandler?(url)
            }
        }
    }

    private func triggerFlowFallback(message: String, opensSettings: Bool = false) {
        isRecording = false
        isProcessing = false
        bannerMessage = message
        bannerActionTitle = opensSettings ? L10n.settingsLabel : L10n.openApp
        bannerOpensSettings = opensSettings
        isPendingStart = false
        flowStartDeadline = nil
        stopFlowStatusTimer()
    }

    private func cancelPendingStart() {
        isPendingStart = false
        bannerMessage = L10n.startCancelled
        flowStartDeadline = nil
        stopFlowStatusTimer()
    }

    func refreshFlowStatus() {
        if audioService == nil {
            audioService = KeyboardAudioService()
        }
        isFlowSessionActive = audioService?.isFlowSessionActive ?? false
    }

    private func startFlowStatusTimer() {
        flowStatusTimer?.invalidate()
        flowStatusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.refreshFlowStatus()

                if self.isPendingStart, self.isFlowSessionActive {
                    self.isPendingStart = false
                    self.flowStartDeadline = nil
                    self.startFlowRecording()
                    return
                }

                if let deadline = self.flowStartDeadline, Date() > deadline, !self.isFlowSessionActive {
                    self.isPendingStart = false
                    self.flowStartDeadline = nil
                    self.bannerMessage = L10n.flowSessionNotActive
                    self.stopFlowStatusTimer()
                }
            }
        }
    }

    private func stopFlowStatusTimer() {
        flowStatusTimer?.invalidate()
        flowStatusTimer = nil
        flowStartDeadline = nil
    }

    private func startFlowLevelPolling() {
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let service = self.audioService else { return }
                self.audioLevels = service.getAudioLevels()
            }
        }
    }

    private func stopLevelPolling() {
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
    }

    private func handleTranscriptionResult(_ text: String?) {
        guard let text = text, !text.isEmpty else {
            self.error = L10n.noTranscription
            self.bannerMessage = self.error
            return
        }

        // Check if selected profile has translation target
        if let profileId = selectedProfileId,
           let profile = availableProfiles.first(where: { $0.id == profileId }),
           let targetLang = profile.translationTargetLanguage {
            pendingTranslationText = text
            let sourceLang = profile.inputLanguage.flatMap { Locale.Language(identifier: $0) }
            let targetLanguage = Locale.Language(identifier: targetLang)
            translationConfig = .init(source: sourceLang, target: targetLanguage)
            isProcessing = true
            return
        }

        self.insertTextHandler?(text)
        self.saveToKeyboardHistory(rawText: text, finalText: text)
    }

    func handleTranslation(_ session: sending TranslationSession) async {
        guard let text = pendingTranslationText else { return }
        do {
            let result = try await session.translate(text)
            await MainActor.run {
                self.insertTextHandler?(result.targetText)
                self.saveToKeyboardHistory(rawText: text, finalText: result.targetText)
                self.isProcessing = false
                self.pendingTranslationText = nil
                self.translationConfig = nil
            }
        } catch {
            logger.error("Translation failed: \(error.localizedDescription)")
            await MainActor.run {
                self.insertTextHandler?(text)
                self.saveToKeyboardHistory(rawText: text, finalText: text)
                self.isProcessing = false
                self.pendingTranslationText = nil
                self.translationConfig = nil
            }
        }
    }

    private func saveToKeyboardHistory(rawText: String, finalText: String) {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: KeyboardConstants.appGroupIdentifier) else {
            return
        }

        let fileURL = groupURL.appending(path: KeyboardConstants.SharedFiles.keyboardHistoryFile)

        var entries: [[String: String]] = []
        if let data = try? Data(contentsOf: fileURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            entries = existing
        }

        let entry: [String: String] = [
            "id": UUID().uuidString,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "rawText": rawText,
            "finalText": finalText,
            "language": currentLanguage
        ]
        entries.append(entry)

        do {
            let data = try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted])
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save keyboard history: \(error.localizedDescription)")
        }
    }

    private func startMaxDurationTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.stopRecording()
            }
        }
    }

    private func stopMaxDurationTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}
