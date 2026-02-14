import Foundation
import SwiftData
import Combine

@MainActor
final class ProfileService: ObservableObject {
    @Published var profiles: [Profile] = []

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init() {
        let schema = Schema([Profile.self])
        let appSupport = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storeDir = appSupport.appendingPathComponent("TypeWhisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let storeURL = storeDir.appendingPathComponent("profiles.store")
        let config = ModelConfiguration(url: storeURL)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            for suffix in ["", "-wal", "-shm"] {
                let url = storeDir.appendingPathComponent("profiles.store\(suffix)")
                try? FileManager.default.removeItem(at: url)
            }
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create profiles ModelContainer after reset: \(error)")
            }
        }
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = true

        fetchProfiles()
    }

    func addProfile(
        name: String,
        inputLanguage: String? = nil,
        translationTargetLanguage: String? = nil,
        selectedTask: String? = nil,
        whisperModeOverride: Bool? = nil,
        engineOverride: String? = nil,
        priority: Int = 0
    ) {
        let profile = Profile(
            name: name,
            priority: priority,
            inputLanguage: inputLanguage,
            translationTargetLanguage: translationTargetLanguage,
            selectedTask: selectedTask,
            whisperModeOverride: whisperModeOverride,
            engineOverride: engineOverride
        )
        modelContext.insert(profile)
        save()
        fetchProfiles()
    }

    func updateProfile(_ profile: Profile) {
        profile.updatedAt = Date()
        save()
        fetchProfiles()
    }

    func deleteProfile(_ profile: Profile) {
        modelContext.delete(profile)
        save()
        fetchProfiles()
    }

    func toggleProfile(_ profile: Profile) {
        profile.isEnabled.toggle()
        profile.updatedAt = Date()
        save()
        fetchProfiles()
    }

    private func fetchProfiles() {
        let descriptor = FetchDescriptor<Profile>(
            sortBy: [SortDescriptor(\.priority, order: .reverse), SortDescriptor(\.name)]
        )
        do {
            profiles = try modelContext.fetch(descriptor)
        } catch {
            profiles = []
        }
        syncProfilesToKeyboard()
    }

    private func syncProfilesToKeyboard() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: TypeWhisperConstants.appGroupIdentifier
        ) else { return }

        let dtos = profiles
            .filter { $0.isEnabled }
            .sorted { $0.priority > $1.priority }
            .map { KeyboardProfileDTO(
                id: $0.id,
                name: $0.name,
                inputLanguage: $0.inputLanguage,
                translationTargetLanguage: $0.translationTargetLanguage,
                priority: $0.priority,
                isEnabled: $0.isEnabled
            )}

        let fileURL = groupURL.appending(path: TypeWhisperConstants.SharedFiles.keyboardProfilesFile)
        do {
            let data = try JSONEncoder().encode(dtos)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ProfileService sync error: \(error)")
        }
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("ProfileService save error: \(error)")
        }
    }
}
