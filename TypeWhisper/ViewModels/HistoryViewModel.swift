import Foundation
import Combine

@MainActor
final class HistoryViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: HistoryViewModel?
    static var shared: HistoryViewModel {
        guard let instance = _shared else {
            fatalError("HistoryViewModel not initialized")
        }
        return instance
    }

    @Published var records: [TranscriptionRecord] = []
    @Published var searchQuery: String = ""

    private let historyService: HistoryService
    private let textDiffService: TextDiffService
    private var cancellables = Set<AnyCancellable>()

    init(historyService: HistoryService, textDiffService: TextDiffService) {
        self.historyService = historyService
        self.textDiffService = textDiffService

        historyService.$records
            .sink { [weak self] records in
                self?.records = records
            }
            .store(in: &cancellables)
    }

    var filteredRecords: [TranscriptionRecord] {
        if searchQuery.isEmpty {
            return records
        }
        return historyService.searchRecords(query: searchQuery)
    }

    func deleteRecord(_ record: TranscriptionRecord) {
        historyService.deleteRecord(record)
    }

    func deleteRecords(_ records: [TranscriptionRecord]) {
        historyService.deleteRecords(records)
    }

    func clearAll() {
        historyService.clearAll()
    }

    func updateRecord(_ record: TranscriptionRecord, finalText: String) {
        historyService.updateRecord(record, finalText: finalText)
    }

    func extractCorrections(original: String, edited: String) -> [CorrectionSuggestion] {
        textDiffService.extractCorrections(original: original, edited: edited)
    }
}
