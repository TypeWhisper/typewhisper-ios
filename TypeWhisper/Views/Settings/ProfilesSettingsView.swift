import SwiftUI

struct ProfilesSettingsView: View {
    @EnvironmentObject private var viewModel: ProfilesViewModel

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
                        Text("Default").tag(nil as String?)
                        Text("Auto-detect").tag("auto" as String?)
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
