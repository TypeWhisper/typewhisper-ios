import SwiftUI
import Translation

@main
struct TypeWhisperApp: App {
    @StateObject private var container = ServiceContainer.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(container)
                .environmentObject(container.recordingViewModel)
                .environmentObject(container.modelManagerViewModel)
                .environmentObject(container.settingsViewModel)
                .environmentObject(container.historyViewModel)
                .environmentObject(container.profilesViewModel)
                .environmentObject(container.dictionaryViewModel)
                .environmentObject(container.snippetsViewModel)
                .environmentObject(container.homeViewModel)
                .environmentObject(container.fileTranscriptionViewModel)
                .environmentObject(container.translationService)
                .environmentObject(container.flowSessionManager)
                .modifier(TranslationTaskModifier(translationService: container.translationService))
                .onOpenURL { url in
                    if url.isFileURL {
                        container.fileTranscriptionViewModel.addFilesFromShare([url])
                        container.flowSessionManager.showFileTranscriptionSheet = true
                        if container.fileTranscriptionViewModel.canTranscribe {
                            container.fileTranscriptionViewModel.transcribeAll()
                        }
                    } else {
                        container.flowSessionManager.handleURL(url)
                    }
                }
                .task {
                    await container.initialize()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        container.flowSessionManager.checkPendingSharedFiles()
                    }
                }
        }
    }
}

private struct TranslationTaskModifier: ViewModifier {
    @ObservedObject var translationService: TranslationService

    func body(content: Content) -> some View {
        content
            .translationTask(translationService.configuration) { session in
                await translationService.handleSession(session)
            }
    }
}
