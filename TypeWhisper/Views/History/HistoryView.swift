import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var viewModel: HistoryViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.records.isEmpty {
                    ContentUnavailableView(
                        "No Recordings",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Your transcription history will appear here.")
                    )
                } else {
                    List {
                        ForEach(viewModel.filteredRecords) { record in
                            NavigationLink(value: record.id) {
                                HistoryRowView(record: record)
                            }
                        }
                        .onDelete { offsets in
                            let records = offsets.map { viewModel.filteredRecords[$0] }
                            viewModel.deleteRecords(records)
                        }
                    }
                    .searchable(text: $viewModel.searchQuery, prompt: "Search transcriptions")
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { id in
                if let record = viewModel.records.first(where: { $0.id == id }) {
                    HistoryDetailView(record: record)
                }
            }
            .toolbar {
                if !viewModel.records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Delete All", systemImage: "trash", role: .destructive) {
                                viewModel.clearAll()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
}

struct HistoryRowView: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.preview)
                .font(.body)
                .lineLimit(2)

            HStack {
                Text(record.timestamp, style: .relative)
                Text("·")
                Text("\(record.wordsCount) words")
                Text("·")
                Text(formatDuration(record.durationSeconds))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }
}
