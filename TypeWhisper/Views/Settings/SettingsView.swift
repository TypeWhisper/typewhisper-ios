import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var modelManager: ModelManagerViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var keyboardActivated = false
    @State private var keyboardHasFullAccess = false

    var body: some View {
        NavigationStack {
            List {
                if !keyboardActivated || !keyboardHasFullAccess {
                    Section("Keyboard") {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label {
                                Text("Keyboard Enabled")
                            } icon: {
                                Image(systemName: keyboardActivated ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(keyboardActivated ? .green : .secondary)
                            }
                        }
                        .disabled(keyboardActivated)

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label {
                                Text("Full Access")
                            } icon: {
                                Image(systemName: keyboardHasFullAccess ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(keyboardHasFullAccess ? .green : .secondary)
                            }
                        }
                        .disabled(keyboardHasFullAccess)
                    }
                }

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
            .onAppear { checkKeyboardSetup() }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    checkKeyboardSetup()
                }
            }
        }
    }

    private func checkKeyboardSetup() {
        guard let defaults = UserDefaults(suiteName: TypeWhisperConstants.appGroupIdentifier) else { return }
        let lastChecked = defaults.double(forKey: TypeWhisperConstants.SharedDefaults.keyboardLastCheckedAt)
        keyboardActivated = lastChecked > 0
        keyboardHasFullAccess = defaults.bool(forKey: TypeWhisperConstants.SharedDefaults.keyboardHasFullAccess)
    }
}
