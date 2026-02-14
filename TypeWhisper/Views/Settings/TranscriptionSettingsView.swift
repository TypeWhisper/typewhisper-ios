import SwiftUI

struct TranscriptionSettingsView: View {
    @EnvironmentObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var recordingVM: RecordingViewModel

    var body: some View {
        List {
            Section("Language") {
                Picker("Input Language", selection: $viewModel.selectedLanguage) {
                    Text("Auto-detect").tag(nil as String?)
                    ForEach(viewModel.availableLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code as String?)
                    }
                }
            }

            Section("Translation") {
                Toggle("Translate after transcription", isOn: $viewModel.translationEnabled)

                if viewModel.translationEnabled {
                    Picker("Target Language", selection: $viewModel.translationTargetLanguage) {
                        ForEach(TranslationService.availableTargetLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                }
            }

            Section("Audio") {
                Toggle("Whisper Mode (Boost Gain)", isOn: $recordingVM.whisperModeEnabled)
                Toggle("Sound Feedback", isOn: $recordingVM.soundFeedbackEnabled)
            }
        }
        .navigationTitle("Transcription")
        .navigationBarTitleDisplayMode(.inline)
    }
}
