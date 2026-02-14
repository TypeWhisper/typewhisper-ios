import Foundation
import Combine

@MainActor
final class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()

    // Services
    let modelManagerService: ModelManagerService
    let audioFileService: AudioFileService
    let audioRecordingService: AudioRecordingService
    let historyService: HistoryService
    let textDiffService: TextDiffService
    let profileService: ProfileService
    let translationService: TranslationService
    let dictionaryService: DictionaryService
    let snippetService: SnippetService
    let soundService: SoundService

    // ViewModels
    let modelManagerViewModel: ModelManagerViewModel
    let fileTranscriptionViewModel: FileTranscriptionViewModel
    let settingsViewModel: SettingsViewModel
    let recordingViewModel: RecordingViewModel
    let historyViewModel: HistoryViewModel
    let profilesViewModel: ProfilesViewModel
    let dictionaryViewModel: DictionaryViewModel
    let snippetsViewModel: SnippetsViewModel
    let homeViewModel: HomeViewModel

    private init() {
        // Services
        modelManagerService = ModelManagerService()
        audioFileService = AudioFileService()
        audioRecordingService = AudioRecordingService()
        historyService = HistoryService()
        textDiffService = TextDiffService()
        profileService = ProfileService()
        translationService = TranslationService()
        dictionaryService = DictionaryService()
        snippetService = SnippetService()
        soundService = SoundService()

        // ViewModels
        modelManagerViewModel = ModelManagerViewModel(modelManager: modelManagerService)
        fileTranscriptionViewModel = FileTranscriptionViewModel(
            modelManager: modelManagerService,
            audioFileService: audioFileService
        )
        settingsViewModel = SettingsViewModel(modelManager: modelManagerService)
        recordingViewModel = RecordingViewModel(
            audioRecordingService: audioRecordingService,
            modelManager: modelManagerService,
            settingsViewModel: settingsViewModel,
            historyService: historyService,
            profileService: profileService,
            translationService: translationService,
            dictionaryService: dictionaryService,
            snippetService: snippetService,
            soundService: soundService
        )
        historyViewModel = HistoryViewModel(
            historyService: historyService,
            textDiffService: textDiffService
        )
        profilesViewModel = ProfilesViewModel(
            profileService: profileService,
            settingsViewModel: settingsViewModel
        )
        dictionaryViewModel = DictionaryViewModel(dictionaryService: dictionaryService)
        snippetsViewModel = SnippetsViewModel(snippetService: snippetService)
        homeViewModel = HomeViewModel(historyService: historyService)

        // Set shared references
        ModelManagerViewModel._shared = modelManagerViewModel
        FileTranscriptionViewModel._shared = fileTranscriptionViewModel
        SettingsViewModel._shared = settingsViewModel
        RecordingViewModel._shared = recordingViewModel
        HistoryViewModel._shared = historyViewModel
        ProfilesViewModel._shared = profilesViewModel
        DictionaryViewModel._shared = dictionaryViewModel
        SnippetsViewModel._shared = snippetsViewModel
        HomeViewModel._shared = homeViewModel

    }

    func initialize() async {
        historyService.purgeOldRecords()
        await modelManagerService.loadAllSavedModels()
    }
}
