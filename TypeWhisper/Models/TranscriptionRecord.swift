import Foundation
import SwiftData

@Model
final class TranscriptionRecord {
    var id: UUID
    var timestamp: Date
    var rawText: String
    var finalText: String
    var appName: String?
    var durationSeconds: Double
    var language: String?
    var engineUsed: String

    var wordsCount: Int { finalText.split(separator: " ").count }
    var preview: String { String(finalText.prefix(100)) }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rawText: String,
        finalText: String,
        appName: String? = nil,
        durationSeconds: Double,
        language: String? = nil,
        engineUsed: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawText = rawText
        self.finalText = finalText
        self.appName = appName
        self.durationSeconds = durationSeconds
        self.language = language
        self.engineUsed = engineUsed
    }
}
