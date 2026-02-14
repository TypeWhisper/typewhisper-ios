import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: SettingsViewModel?
    static var shared: SettingsViewModel {
        guard let instance = _shared else {
            fatalError("SettingsViewModel not initialized")
        }
        return instance
    }

    @Published var selectedLanguage: String? {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: "selectedLanguage")
        }
    }
    @Published var selectedTask: TranscriptionTask {
        didSet {
            UserDefaults.standard.set(selectedTask.rawValue, forKey: "selectedTask")
        }
    }
    @Published var translationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(translationEnabled, forKey: "translationEnabled")
        }
    }
    @Published var translationTargetLanguage: String {
        didSet {
            UserDefaults.standard.set(translationTargetLanguage, forKey: "translationTargetLanguage")
        }
    }

    private let modelManager: ModelManagerService
    private var cancellables = Set<AnyCancellable>()

    init(modelManager: ModelManagerService) {
        self.modelManager = modelManager
        self.selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage")
        self.selectedTask = UserDefaults.standard.string(forKey: "selectedTask")
            .flatMap { TranscriptionTask(rawValue: $0) } ?? .transcribe
        self.translationEnabled = UserDefaults.standard.bool(forKey: "translationEnabled")
        self.translationTargetLanguage = UserDefaults.standard.string(forKey: "translationTargetLanguage") ?? "en"
    }

    var availableLanguages: [(code: String, name: String)] {
        let engine = modelManager.activeEngine ?? modelManager.engine(for: .whisper)
        return engine.supportedLanguages.map { code in
            let name = Locale.current.localizedString(forLanguageCode: code) ?? code
            return (code: code, name: name)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var supportsTranslation: Bool {
        modelManager.activeEngine?.supportsTranslation ?? true
    }
}
