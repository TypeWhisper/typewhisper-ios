import Foundation
import Combine
import UIKit
import UniformTypeIdentifiers

@MainActor
final class FileTranscriptionViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: FileTranscriptionViewModel?
    static var shared: FileTranscriptionViewModel {
        guard let instance = _shared else {
            fatalError("FileTranscriptionViewModel not initialized")
        }
        return instance
    }

    struct FileItem: Identifiable {
        let id = UUID()
        let url: URL
        var state: FileItemState = .pending
        var result: TranscriptionResult?
        var errorMessage: String?

        var fileName: String { url.lastPathComponent }
    }

    enum FileItemState: Equatable {
        case pending
        case loading
        case transcribing
        case done
        case error
    }

    enum BatchState: Equatable {
        case idle
        case processing
        case done
    }

    @Published var files: [FileItem] = []
    @Published var batchState: BatchState = .idle
    @Published var currentIndex: Int = 0
    @Published var selectedLanguage: String? = nil
    @Published var selectedTask: TranscriptionTask = .transcribe

    private let modelManager: ModelManagerService
    private let audioFileService: AudioFileService

    static let allowedContentTypes: [UTType] = [
        .wav, .mp3, .mpeg4Audio, .aiff, .audio,
        .mpeg4Movie, .quickTimeMovie, .avi, .movie
    ]

    init(modelManager: ModelManagerService, audioFileService: AudioFileService) {
        self.modelManager = modelManager
        self.audioFileService = audioFileService
    }

    var canTranscribe: Bool {
        !files.isEmpty && modelManager.activeEngine?.isModelLoaded == true && batchState != .processing
    }

    var hasResults: Bool {
        files.contains { $0.state == .done }
    }

    var totalFiles: Int { files.count }
    var completedFiles: Int { files.filter { $0.state == .done }.count }

    func addFiles(_ urls: [URL]) {
        let validExtensions = AudioFileService.supportedExtensions
        let existingURLs = Set(files.map(\.url))

        let newFiles = urls
            .filter { validExtensions.contains($0.pathExtension.lowercased()) }
            .filter { !existingURLs.contains($0) }
            .map { FileItem(url: $0) }

        files.append(contentsOf: newFiles)
    }

    func removeFile(_ item: FileItem) {
        files.removeAll { $0.id == item.id }
        if files.isEmpty { batchState = .idle }
    }

    func transcribeAll() {
        guard canTranscribe else { return }

        batchState = .processing
        currentIndex = 0

        for i in files.indices {
            if files[i].state != .done {
                files[i].state = .pending
                files[i].result = nil
                files[i].errorMessage = nil
            }
        }

        Task {
            for i in files.indices {
                guard batchState == .processing else { break }
                guard files[i].state != .done else { continue }
                currentIndex = i
                await transcribeFile(at: i)
            }
            batchState = .done
        }
    }

    private func transcribeFile(at index: Int) async {
        files[index].state = .loading

        do {
            let samples = try await audioFileService.loadAudioSamples(from: files[index].url)
            files[index].state = .transcribing

            let result = try await modelManager.transcribe(
                audioSamples: samples,
                language: selectedLanguage,
                task: selectedTask
            )

            files[index].result = result
            files[index].state = .done
        } catch {
            files[index].state = .error
            files[index].errorMessage = error.localizedDescription
        }
    }

    func copyText(for item: FileItem) {
        guard let text = item.result?.text, !text.isEmpty else { return }
        UIPasteboard.general.string = text
    }

    func copyAllText() {
        let allText = files
            .compactMap { $0.result?.text }
            .joined(separator: "\n\n")
        guard !allText.isEmpty else { return }
        UIPasteboard.general.string = allText
    }

    func reset() {
        files = []
        batchState = .idle
        currentIndex = 0
    }
}
