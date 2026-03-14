import Foundation
import Combine
#if canImport(ActivityKit)
import ActivityKit
#endif

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
    let flowSessionManager: FlowSessionManager
    #if canImport(ActivityKit)
    let liveActivityService: LiveActivityService
    #endif

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
        flowSessionManager = FlowSessionManager(modelManager: modelManagerService)
        #if canImport(ActivityKit)
        liveActivityService = LiveActivityService()
        #endif

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

        // Wire Live Activity
        #if canImport(ActivityKit)
        recordingViewModel.liveActivityService = liveActivityService
        liveActivityService.durationProvider = { [weak recordingViewModel] in
            recordingViewModel?.recordingDuration ?? 0
        }
        liveActivityService.audioLevelProvider = { [weak recordingViewModel] in
            recordingViewModel?.audioLevel ?? 0
        }
        liveActivityService.isRecordingProvider = { [weak recordingViewModel] in
            recordingViewModel?.state == .recording
        }

        StopRecordingLiveActivityIntent.handler = { [weak recordingViewModel] in
            recordingViewModel?.stopRecording()
        }
        TogglePauseLiveActivityIntent.handler = { [weak recordingViewModel] in
            guard let vm = recordingViewModel else { return }
            if vm.state == .paused {
                vm.resumeRecording()
            } else if vm.state == .recording {
                vm.pauseRecording()
            }
        }
        #endif

        // Wire Share Extension handling
        flowSessionManager.fileTranscriptionViewModel = fileTranscriptionViewModel

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
        historyService.importKeyboardHistory()
        historyService.purgeOldRecords()
        flowSessionManager.checkPendingSharedFiles()
        await modelManagerService.loadAllSavedModels()
    }
}
