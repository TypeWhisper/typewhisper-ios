import Foundation
import Combine

struct ActivityDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let wordCount: Int
}

@MainActor
final class HomeViewModel: ObservableObject {
    nonisolated(unsafe) static var _shared: HomeViewModel?
    static var shared: HomeViewModel {
        guard let instance = _shared else {
            fatalError("HomeViewModel not initialized")
        }
        return instance
    }

    @Published var wordsCount: Int = 0
    @Published var recordingsCount: Int = 0
    @Published var timeSaved: String = "—"

    private let historyService: HistoryService
    private var cancellables = Set<AnyCancellable>()

    init(historyService: HistoryService) {
        self.historyService = historyService

        historyService.$records
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        refresh()
    }

    func refresh() {
        let records = historyService.records
        recordingsCount = records.count
        wordsCount = records.reduce(0) { $0 + $1.wordsCount }

        let totalMinutes = records.reduce(0.0) { $0 + $1.durationSeconds } / 60.0
        let typingMinutes = Double(wordsCount) / 45.0
        let savedMinutes = typingMinutes - totalMinutes
        if savedMinutes > 0 {
            let mins = Int(savedMinutes)
            if mins >= 60 {
                let hours = mins / 60
                let remainder = mins % 60
                timeSaved = "\(hours)h \(remainder)m"
            } else {
                timeSaved = "\(mins)m"
            }
        } else {
            timeSaved = "—"
        }
    }
}
