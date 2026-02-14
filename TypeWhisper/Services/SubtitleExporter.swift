import Foundation
import UniformTypeIdentifiers

enum SubtitleFormat: String, CaseIterable {
    case srt
    case vtt

    var fileExtension: String { rawValue }

    var utType: UTType {
        switch self {
        case .srt: UTType(filenameExtension: "srt") ?? .plainText
        case .vtt: UTType(filenameExtension: "vtt") ?? .plainText
        }
    }
}

enum SubtitleExporter {

    static func exportSRT(segments: [TranscriptionSegment]) -> String {
        segments.enumerated().map { index, segment in
            let start = formatSRTTime(segment.start)
            let end = formatSRTTime(segment.end)
            return "\(index + 1)\n\(start) --> \(end)\n\(segment.text)"
        }.joined(separator: "\n\n")
    }

    static func exportVTT(segments: [TranscriptionSegment]) -> String {
        var lines = ["WEBVTT", ""]
        for (index, segment) in segments.enumerated() {
            let start = formatVTTTime(segment.start)
            let end = formatVTTTime(segment.end)
            lines.append("\(index + 1)")
            lines.append("\(start) --> \(end)")
            lines.append(segment.text)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func formatSRTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let millis = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, millis)
    }

    private static func formatVTTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let millis = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, millis)
    }
}
