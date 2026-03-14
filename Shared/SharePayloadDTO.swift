import Foundation

struct SharePayloadDTO: Codable {
    let id: UUID
    let timestamp: Date
    let files: [SharedFileEntry]

    struct SharedFileEntry: Codable {
        let fileName: String
        let localPath: String
    }
}
