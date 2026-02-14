import Foundation
import SwiftData
import Combine

@MainActor
class DictionaryService: ObservableObject {
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    @Published private(set) var entries: [DictionaryEntry] = []

    var terms: [DictionaryEntry] {
        entries.filter { $0.type == .term && $0.isEnabled }
    }

    var corrections: [DictionaryEntry] {
        entries.filter { $0.type == .correction && $0.isEnabled }
    }

    var termsCount: Int {
        entries.filter { $0.type == .term }.count
    }

    var correctionsCount: Int {
        entries.filter { $0.type == .correction }.count
    }

    var enabledTermsCount: Int { terms.count }
    var enabledCorrectionsCount: Int { corrections.count }

    init() {
        setupModelContainer()
    }

    private func setupModelContainer() {
        let schema = Schema([DictionaryEntry.self])
        let appSupport = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storeDir = appSupport.appendingPathComponent("TypeWhisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let storeURL = storeDir.appendingPathComponent("dictionary.store")
        let config = ModelConfiguration(url: storeURL)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            for suffix in ["", "-wal", "-shm"] {
                let url = storeDir.appendingPathComponent("dictionary.store\(suffix)")
                try? FileManager.default.removeItem(at: url)
            }
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create dictionary ModelContainer after reset: \(error)")
            }
        }
        modelContext = ModelContext(modelContainer!)
        modelContext?.autosaveEnabled = true

        loadEntries()
    }

    func loadEntries() {
        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<DictionaryEntry>(
                sortBy: [
                    SortDescriptor(\.entryType, order: .forward),
                    SortDescriptor(\.original, order: .forward)
                ]
            )
            entries = try context.fetch(descriptor)
        } catch {
            print("DictionaryService: Failed to fetch entries: \(error)")
        }
    }

    func addEntry(type: DictionaryEntryType, original: String, replacement: String? = nil, caseSensitive: Bool = false) {
        guard let context = modelContext else { return }
        if entries.contains(where: { $0.original.lowercased() == original.lowercased() && $0.type == type }) { return }

        let entry = DictionaryEntry(type: type, original: original, replacement: replacement, caseSensitive: caseSensitive)
        context.insert(entry)
        do { try context.save(); loadEntries() } catch { print("DictionaryService: Failed to save entry: \(error)") }
    }

    func updateEntry(_ entry: DictionaryEntry, original: String, replacement: String?, caseSensitive: Bool) {
        guard let context = modelContext else { return }
        entry.original = original
        entry.replacement = replacement
        entry.caseSensitive = caseSensitive
        do { try context.save(); loadEntries() } catch { print("DictionaryService: Failed to update entry: \(error)") }
    }

    func deleteEntry(_ entry: DictionaryEntry) {
        guard let context = modelContext else { return }
        context.delete(entry)
        do { try context.save(); loadEntries() } catch { print("DictionaryService: Failed to delete entry: \(error)") }
    }

    func toggleEntry(_ entry: DictionaryEntry) {
        guard let context = modelContext else { return }
        entry.isEnabled.toggle()
        do { try context.save(); loadEntries() } catch { print("DictionaryService: Failed to toggle entry: \(error)") }
    }

    func addEntries(_ items: [(type: DictionaryEntryType, original: String, replacement: String?, caseSensitive: Bool)]) {
        guard let context = modelContext, !items.isEmpty else { return }
        let existingOriginals = Set(entries.map { "\($0.type.rawValue):\($0.original.lowercased())" })
        for item in items {
            let key = "\(item.type.rawValue):\(item.original.lowercased())"
            guard !existingOriginals.contains(key) else { continue }
            let entry = DictionaryEntry(type: item.type, original: item.original, replacement: item.replacement, caseSensitive: item.caseSensitive)
            context.insert(entry)
        }
        do { try context.save(); loadEntries() } catch { print("DictionaryService: Failed to batch save entries: \(error)") }
    }

    func deleteEntries(_ entriesToDelete: [DictionaryEntry]) {
        guard let context = modelContext, !entriesToDelete.isEmpty else { return }
        for entry in entriesToDelete { context.delete(entry) }
        do { try context.save(); loadEntries() } catch { print("DictionaryService: Failed to batch delete entries: \(error)") }
    }

    func getTermsForPrompt() -> String? {
        let enabledTerms = terms.map { $0.original }
        guard !enabledTerms.isEmpty else { return nil }
        return enabledTerms.joined(separator: ", ")
    }

    func applyCorrections(to text: String) -> String {
        var result = text
        for correction in corrections {
            guard let replacement = correction.replacement else { continue }
            if correction.caseSensitive {
                result = result.replacingOccurrences(of: correction.original, with: replacement)
            } else {
                result = result.replacingOccurrences(of: correction.original, with: replacement, options: .caseInsensitive)
            }
        }
        return result
    }

    func learnCorrection(original: String, replacement: String) {
        guard original.lowercased() != replacement.lowercased() else { return }
        if entries.contains(where: { $0.type == .correction && $0.original.lowercased() == original.lowercased() }) { return }
        addEntry(type: .correction, original: original, replacement: replacement, caseSensitive: false)
    }
}
