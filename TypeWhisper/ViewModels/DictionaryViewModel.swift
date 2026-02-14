import Foundation
import Combine

@MainActor
final class DictionaryViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: DictionaryViewModel?
    static var shared: DictionaryViewModel {
        guard let instance = _shared else {
            fatalError("DictionaryViewModel not initialized")
        }
        return instance
    }

    @Published var entries: [DictionaryEntry] = []
    @Published var searchQuery: String = ""

    private let dictionaryService: DictionaryService
    private var cancellables = Set<AnyCancellable>()

    init(dictionaryService: DictionaryService) {
        self.dictionaryService = dictionaryService

        dictionaryService.$entries
            .sink { [weak self] entries in
                self?.entries = entries
            }
            .store(in: &cancellables)
    }

    var filteredEntries: [DictionaryEntry] {
        guard !searchQuery.isEmpty else { return entries }
        let query = searchQuery.lowercased()
        return entries.filter {
            $0.original.lowercased().contains(query) ||
            ($0.replacement?.lowercased().contains(query) ?? false)
        }
    }

    var termsCount: Int { dictionaryService.termsCount }
    var correctionsCount: Int { dictionaryService.correctionsCount }

    func addEntry(type: DictionaryEntryType, original: String, replacement: String?, caseSensitive: Bool) {
        dictionaryService.addEntry(type: type, original: original, replacement: replacement, caseSensitive: caseSensitive)
    }

    func updateEntry(_ entry: DictionaryEntry, original: String, replacement: String?, caseSensitive: Bool) {
        dictionaryService.updateEntry(entry, original: original, replacement: replacement, caseSensitive: caseSensitive)
    }

    func deleteEntry(_ entry: DictionaryEntry) {
        dictionaryService.deleteEntry(entry)
    }

    func toggleEntry(_ entry: DictionaryEntry) {
        dictionaryService.toggleEntry(entry)
    }

    func addEntries(_ items: [(type: DictionaryEntryType, original: String, replacement: String?, caseSensitive: Bool)]) {
        dictionaryService.addEntries(items)
    }

    func learnCorrection(original: String, replacement: String) {
        dictionaryService.learnCorrection(original: original, replacement: replacement)
    }
}
