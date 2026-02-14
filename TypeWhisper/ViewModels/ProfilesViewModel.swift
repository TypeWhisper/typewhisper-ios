import Foundation
import Combine

@MainActor
final class ProfilesViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: ProfilesViewModel?
    static var shared: ProfilesViewModel {
        guard let instance = _shared else {
            fatalError("ProfilesViewModel not initialized")
        }
        return instance
    }

    @Published var profiles: [Profile] = []

    // Editor state
    @Published var showingEditor = false
    @Published var editingProfile: Profile?
    @Published var editorName = ""
    @Published var editorInputLanguage: String?
    @Published var editorTranslationTargetLanguage: String?
    @Published var editorSelectedTask: String?
    @Published var editorWhisperModeOverride: Bool?
    @Published var editorPriority: Int = 0

    private let profileService: ProfileService
    let settingsViewModel: SettingsViewModel
    private var cancellables = Set<AnyCancellable>()

    init(profileService: ProfileService, settingsViewModel: SettingsViewModel) {
        self.profileService = profileService
        self.settingsViewModel = settingsViewModel
        self.profiles = profileService.profiles

        profileService.$profiles
            .dropFirst()
            .sink { [weak self] profiles in
                DispatchQueue.main.async {
                    self?.profiles = profiles
                }
            }
            .store(in: &cancellables)
    }

    func addProfile() {
        profileService.addProfile(
            name: editorName,
            inputLanguage: editorInputLanguage,
            translationTargetLanguage: editorTranslationTargetLanguage,
            selectedTask: editorSelectedTask,
            whisperModeOverride: editorWhisperModeOverride,
            priority: editorPriority
        )
    }

    func saveProfile() {
        if let profile = editingProfile {
            profile.name = editorName
            profile.inputLanguage = editorInputLanguage
            profile.translationTargetLanguage = editorTranslationTargetLanguage
            profile.selectedTask = editorSelectedTask
            profile.whisperModeOverride = editorWhisperModeOverride
            profile.priority = editorPriority
            profileService.updateProfile(profile)
        } else {
            addProfile()
        }
        showingEditor = false
    }

    func deleteProfile(_ profile: Profile) {
        profileService.deleteProfile(profile)
    }

    func toggleProfile(_ profile: Profile) {
        profileService.toggleProfile(profile)
    }

    func prepareNewProfile() {
        editingProfile = nil
        editorName = ""
        editorInputLanguage = nil
        editorTranslationTargetLanguage = nil
        editorSelectedTask = nil
        editorWhisperModeOverride = nil
        editorPriority = 0
        showingEditor = true
    }

    func prepareEditProfile(_ profile: Profile) {
        editingProfile = profile
        editorName = profile.name
        editorInputLanguage = profile.inputLanguage
        editorTranslationTargetLanguage = profile.translationTargetLanguage
        editorSelectedTask = profile.selectedTask
        editorWhisperModeOverride = profile.whisperModeOverride
        editorPriority = profile.priority
        showingEditor = true
    }

    func profileSubtitle(_ profile: Profile) -> String {
        var parts: [String] = []
        if let lang = profile.inputLanguage {
            let name = Locale.current.localizedString(forLanguageCode: lang) ?? lang
            parts.append(name)
        }
        if let lang = profile.translationTargetLanguage {
            let name = Locale.current.localizedString(forLanguageCode: lang) ?? lang
            parts.append("→ " + name)
        }
        return parts.joined(separator: " · ")
    }
}
