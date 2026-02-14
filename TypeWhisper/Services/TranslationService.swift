import Foundation
import os
import Translation

@MainActor
final class TranslationService: ObservableObject {
    @Published var configuration: TranslationSession.Configuration?

    private var sourceText = ""
    private var continuation: CheckedContinuation<String, Error>?
    private static let logger = Logger(subsystem: "com.typewhisper.ios", category: "Translation")

    func translate(text: String, from source: Locale.Language? = nil, to target: Locale.Language) async throws -> String {
        if let pending = continuation {
            Self.logger.warning("Cancelling pending translation")
            pending.resume(returning: sourceText)
            continuation = nil
        }

        configuration = nil
        try await Task.sleep(for: .milliseconds(50))

        sourceText = text

        return try await withCheckedThrowingContinuation { cont in
            continuation = cont
            configuration = .init(source: source, target: target)
            Self.logger.info("Translation requested from \(source?.minimalIdentifier ?? "auto") to \(target.minimalIdentifier)")

            Task { [weak self] in
                try await Task.sleep(for: .seconds(15))
                guard let self else { return }
                if let pending = self.continuation {
                    Self.logger.error("Translation timed out after 15s, returning original text")
                    pending.resume(returning: self.sourceText)
                    self.continuation = nil
                    self.configuration = nil
                }
            }
        }
    }

    func handleSession(_ session: sending TranslationSession) async {
        do {
            let result = try await session.translate(sourceText)
            Self.logger.info("Translation completed successfully")
            continuation?.resume(returning: result.targetText)
        } catch {
            Self.logger.error("Translation failed: \(error.localizedDescription), returning original text")
            continuation?.resume(returning: sourceText)
        }
        continuation = nil
    }

    static let availableTargetLanguages: [(code: String, name: String)] = {
        let codes = [
            "ar", "de", "en", "es", "fr", "hi", "id", "it", "ja", "ko",
            "nl", "pl", "pt", "ru", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant",
        ]
        return codes.compactMap { code in
            let name = Locale.current.localizedString(forLanguageCode: code) ?? code
            return (code: code, name: name)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()
}
