import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var modelManager: ModelManagerViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ModelManagerView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Models")
                                if let name = modelManager.activeModelName {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("No model loaded")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        } icon: {
                            Image(systemName: "cpu")
                        }
                    }

                    NavigationLink {
                        TranscriptionSettingsView()
                    } label: {
                        Label("Transcription", systemImage: "waveform")
                    }
                }

                Section {
                    NavigationLink {
                        DictionarySettingsView()
                    } label: {
                        Label("Dictionary", systemImage: "book.closed")
                    }

                    NavigationLink {
                        SnippetsSettingsView()
                    } label: {
                        Label("Snippets", systemImage: "text.insert")
                    }

                    NavigationLink {
                        ProfilesSettingsView()
                    } label: {
                        Label("Profiles", systemImage: "person.crop.rectangle.stack")
                    }
                }

                Section {
                    NavigationLink {
                        FileTranscriptionView()
                    } label: {
                        Label("File Transcription", systemImage: "doc.text")
                    }

                    NavigationLink {
                        GeneralSettingsView()
                    } label: {
                        Label("General", systemImage: "gearshape")
                    }
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
