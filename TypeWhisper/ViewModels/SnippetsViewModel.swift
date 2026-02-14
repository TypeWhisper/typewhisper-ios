import Foundation
import Combine

@MainActor
final class SnippetsViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: SnippetsViewModel?
    static var shared: SnippetsViewModel {
        guard let instance = _shared else {
            fatalError("SnippetsViewModel not initialized")
        }
        return instance
    }

    @Published var snippets: [Snippet] = []

    private let snippetService: SnippetService
    private var cancellables = Set<AnyCancellable>()

    init(snippetService: SnippetService) {
        self.snippetService = snippetService

        snippetService.$snippets
            .sink { [weak self] snippets in
                self?.snippets = snippets
            }
            .store(in: &cancellables)
    }

    var enabledCount: Int { snippetService.enabledSnippetsCount }

    func addSnippet(trigger: String, replacement: String, caseSensitive: Bool) {
        snippetService.addSnippet(trigger: trigger, replacement: replacement, caseSensitive: caseSensitive)
    }

    func updateSnippet(_ snippet: Snippet, trigger: String, replacement: String, caseSensitive: Bool) {
        snippetService.updateSnippet(snippet, trigger: trigger, replacement: replacement, caseSensitive: caseSensitive)
    }

    func deleteSnippet(_ snippet: Snippet) {
        snippetService.deleteSnippet(snippet)
    }

    func toggleSnippet(_ snippet: Snippet) {
        snippetService.toggleSnippet(snippet)
    }
}
