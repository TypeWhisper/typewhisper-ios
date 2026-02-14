import Foundation
import SwiftData

@Model
final class Profile {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var priority: Int
    var inputLanguage: String?
    var translationTargetLanguage: String?
    var selectedTask: String?
    var whisperModeOverride: Bool?
    var engineOverride: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        priority: Int = 0,
        inputLanguage: String? = nil,
        translationTargetLanguage: String? = nil,
        selectedTask: String? = nil,
        whisperModeOverride: Bool? = nil,
        engineOverride: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.priority = priority
        self.inputLanguage = inputLanguage
        self.translationTargetLanguage = translationTargetLanguage
        self.selectedTask = selectedTask
        self.whisperModeOverride = whisperModeOverride
        self.engineOverride = engineOverride
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
