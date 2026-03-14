import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        processSharedItems()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconImage = UIImage(systemName: "waveform")
        let iconView = UIImageView(image: iconImage)
        iconView.tintColor = .label
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40)
        ])

        statusLabel.text = "Preparing..."
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = .secondaryLabel

        spinner.startAnimating()

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(spinner)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func processSharedItems() {
        Task {
            do {
                let files = try await extractFiles()

                if files.isEmpty {
                    showError("No supported audio or video files found.")
                    return
                }

                try writePayload(files: files)

                await MainActor.run {
                    _ = openContainingApp()
                }

                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func extractFiles() async throws -> [(fileName: String, localPath: String)] {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return []
        }

        let supportedExtensions = TypeWhisperConstants.supportedAudioVideoExtensions

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: TypeWhisperConstants.appGroupIdentifier
        ) else {
            throw ShareError.noAppGroup
        }

        let sessionID = UUID().uuidString
        let sessionDir = containerURL
            .appendingPathComponent(TypeWhisperConstants.SharedFiles.sharedFilesDirectory)
            .appendingPathComponent(sessionID)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        var result: [(fileName: String, localPath: String)] = []

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if let url = try await loadFile(from: provider) {
                    let ext = url.pathExtension.lowercased()
                    guard supportedExtensions.contains(ext) else { continue }

                    let fileName = url.lastPathComponent
                    let destURL = sessionDir.appendingPathComponent(fileName)
                    try FileManager.default.copyItem(at: url, to: destURL)

                    let relativePath = "\(sessionID)/\(fileName)"
                    result.append((fileName: fileName, localPath: relativePath))
                }
            }
        }

        return result
    }

    private func loadFile(from provider: NSItemProvider) async throws -> URL? {
        let fileTypes: [UTType] = [.audio, .movie, .data]

        for type in fileTypes {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                return try await withCheckedThrowingContinuation { continuation in
                    provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }
                        guard let url else {
                            continuation.resume(returning: nil)
                            return
                        }
                        // Copy to temp because the provided URL is only valid during this callback
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension(url.pathExtension)
                        do {
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            continuation.resume(returning: tempURL)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }

        return nil
    }

    private func writePayload(files: [(fileName: String, localPath: String)]) throws {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: TypeWhisperConstants.appGroupIdentifier
        ) else {
            throw ShareError.noAppGroup
        }

        let payload = SharePayloadDTO(
            id: UUID(),
            timestamp: Date(),
            files: files.map { .init(fileName: $0.fileName, localPath: $0.localPath) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(payload)
        let payloadURL = containerURL.appendingPathComponent(
            TypeWhisperConstants.SharedFiles.pendingShareFile
        )
        try data.write(to: payloadURL, options: .atomic)
    }

    @MainActor
    private func showError(_ message: String) {
        statusLabel.text = message
        statusLabel.textColor = .systemRed
        spinner.stopAnimating()

        Task {
            try? await Task.sleep(for: .seconds(2))
            extensionContext?.cancelRequest(withError: ShareError.userMessage(message))
        }
    }

    // Bluesky-style: walk responder chain, find UIApplication, call open()
    @objc private func openContainingApp() -> Bool {
        guard let url = URL(string: "typewhisper://share") else { return false }
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url)
                return true
            }
            responder = responder?.next
        }
        return false
    }

    enum ShareError: LocalizedError {
        case noAppGroup
        case userMessage(String)

        var errorDescription: String? {
            switch self {
            case .noAppGroup: "Could not access shared container."
            case .userMessage(let msg): msg
            }
        }
    }
}
