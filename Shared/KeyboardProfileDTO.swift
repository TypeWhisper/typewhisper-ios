import Foundation

struct KeyboardProfileDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let inputLanguage: String?
    let translationTargetLanguage: String?
    let priority: Int
    let isEnabled: Bool
}
