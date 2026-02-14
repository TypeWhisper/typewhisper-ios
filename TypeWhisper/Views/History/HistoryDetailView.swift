import SwiftUI

struct HistoryDetailView: View {
    let record: TranscriptionRecord
    @EnvironmentObject private var viewModel: HistoryViewModel
    @State private var editedText: String = ""
    @State private var isEditing = false
    @State private var showCopied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Label(record.timestamp.formatted(date: .long, time: .shortened), systemImage: "calendar")
                    Label("\(record.wordsCount) words", systemImage: "text.word.spacing")
                    Label(formatDuration(record.durationSeconds), systemImage: "timer")
                    Label(record.engineUsed, systemImage: "cpu")
                    if let language = record.language {
                        Label(Locale.current.localizedString(forLanguageCode: language) ?? language, systemImage: "globe")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                // Text content
                if isEditing {
                    TextEditor(text: $editedText)
                        .frame(minHeight: 200)
                        .border(.separator)
                } else {
                    Text(record.finalText)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isEditing {
                    Button("Save") {
                        viewModel.updateRecord(record, finalText: editedText)
                        isEditing = false
                    }
                    Button("Cancel", role: .cancel) {
                        isEditing = false
                    }
                } else {
                    Button {
                        UIPasteboard.general.string = record.finalText
                        showCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            showCopied = false
                        }
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    }

                    Button {
                        editedText = record.finalText
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }

                    ShareLink(item: record.finalText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            editedText = record.finalText
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }
}
