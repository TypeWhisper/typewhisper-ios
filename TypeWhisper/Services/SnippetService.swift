import Foundation
import SwiftData
import Combine

@MainActor
class SnippetService: ObservableObject {
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    @Published private(set) var snippets: [Snippet] = []

    var enabledSnippetsCount: Int {
        snippets.filter { $0.isEnabled }.count
    }

    init() {
        setupModelContainer()
    }

    private func setupModelContainer() {
        let schema = Schema([Snippet.self])
        let appSupport = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storeDir = appSupport.appendingPathComponent("TypeWhisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let storeURL = storeDir.appendingPathComponent("snippets.store")
        let config = ModelConfiguration(url: storeURL)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            for suffix in ["", "-wal", "-shm"] {
                let url = storeDir.appendingPathComponent("snippets.store\(suffix)")
                try? FileManager.default.removeItem(at: url)
            }
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create snippets ModelContainer after reset: \(error)")
            }
        }
        modelContext = ModelContext(modelContainer!)
        modelContext?.autosaveEnabled = true

        loadSnippets()
    }

    func loadSnippets() {
        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<Snippet>(sortBy: [SortDescriptor(\.trigger, order: .forward)])
            snippets = try context.fetch(descriptor)
        } catch {
            print("SnippetService: Failed to fetch snippets: \(error)")
        }
    }

    func addSnippet(trigger: String, replacement: String, caseSensitive: Bool = false) {
        guard let context = modelContext else { return }
        if snippets.contains(where: { $0.trigger == trigger }) { return }
        let snippet = Snippet(trigger: trigger, replacement: replacement, caseSensitive: caseSensitive)
        context.insert(snippet)
        do { try context.save(); loadSnippets() } catch { print("SnippetService: Failed to save snippet: \(error)") }
    }

    func updateSnippet(_ snippet: Snippet, trigger: String, replacement: String, caseSensitive: Bool) {
        guard let context = modelContext else { return }
        snippet.trigger = trigger
        snippet.replacement = replacement
        snippet.caseSensitive = caseSensitive
        do { try context.save(); loadSnippets() } catch { print("SnippetService: Failed to update snippet: \(error)") }
    }

    func deleteSnippet(_ snippet: Snippet) {
        guard let context = modelContext else { return }
        context.delete(snippet)
        do { try context.save(); loadSnippets() } catch { print("SnippetService: Failed to delete snippet: \(error)") }
    }

    func toggleSnippet(_ snippet: Snippet) {
        guard let context = modelContext else { return }
        snippet.isEnabled.toggle()
        do { try context.save(); loadSnippets() } catch { print("SnippetService: Failed to toggle snippet: \(error)") }
    }

    func applySnippets(to text: String) -> String {
        var result = text
        for snippet in snippets where snippet.isEnabled {
            let searchTrigger = snippet.caseSensitive ? snippet.trigger : snippet.trigger.lowercased()
            let searchText = snippet.caseSensitive ? result : result.lowercased()
            if searchText.contains(searchTrigger) {
                let replacement = snippet.processedReplacement()
                if snippet.caseSensitive {
                    result = result.replacingOccurrences(of: snippet.trigger, with: replacement)
                } else {
                    result = result.replacingOccurrences(of: snippet.trigger, with: replacement, options: .caseInsensitive)
                }
            }
        }
        return result
    }
}
