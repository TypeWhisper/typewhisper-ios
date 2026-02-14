import SwiftUI

struct ProfilesSettingsView: View {
    @EnvironmentObject private var viewModel: ProfilesViewModel

    private struct SpeechLanguage: Identifiable {
        let code: String
        let name: String
        var id: String { code }
    }

    private static let speechLanguages: [SpeechLanguage] = [
        SpeechLanguage(code: "de-DE", name: "Deutsch"),
        SpeechLanguage(code: "en-US", name: "English (US)"),
        SpeechLanguage(code: "en-GB", name: "English (UK)"),
        SpeechLanguage(code: "es-ES", name: "Español"),
        SpeechLanguage(code: "fr-FR", name: "Français"),
        SpeechLanguage(code: "it-IT", name: "Italiano"),
        SpeechLanguage(code: "pt-BR", name: "Português (BR)"),
        SpeechLanguage(code: "nl-NL", name: "Nederlands"),
        SpeechLanguage(code: "pl-PL", name: "Polski"),
        SpeechLanguage(code: "ru-RU", name: "Русский"),
        SpeechLanguage(code: "ja-JP", name: "日本語"),
        SpeechLanguage(code: "zh-CN", name: "中文 (简体)"),
        SpeechLanguage(code: "ko-KR", name: "한국어"),
        SpeechLanguage(code: "tr-TR", name: "Türkçe"),
        SpeechLanguage(code: "ar-SA", name: "العربية"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(viewModel.profiles) { profile in
                    Button {
                        viewModel.prepareEditProfile(profile)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                let subtitle = viewModel.profileSubtitle(profile)
                                if !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { profile.isEnabled },
                                set: { _ in viewModel.toggleProfile(profile) }
                            ))
                            .labelsHidden()
                        }
                    }
                }
                .onDelete { offsets in
                    let profiles = offsets.map { viewModel.profiles[$0] }
                    for profile in profiles {
                        viewModel.deleteProfile(profile)
                    }
                }
            } footer: {
                Text("Profiles let you save language and translation settings for quick switching.")
            }
        }
        .navigationTitle("Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.prepareNewProfile()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingEditor) {
            NavigationStack {
                Form {
                    TextField("Name", text: $viewModel.editorName)

                    Picker("Language", selection: $viewModel.editorInputLanguage) {
                        Text("Auto-detect").tag(nil as String?)
                        ForEach(ProfilesSettingsView.speechLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code as String?)
                        }
                    }

                    Picker("Translation", selection: $viewModel.editorTranslationTargetLanguage) {
                        Text("None").tag(nil as String?)
                        ForEach(TranslationService.availableTargetLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code as String?)
                        }
                    }
                }
                .navigationTitle(viewModel.editingProfile == nil ? "New Profile" : "Edit Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { viewModel.showingEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.saveProfile()
                        }
                        .disabled(viewModel.editorName.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
