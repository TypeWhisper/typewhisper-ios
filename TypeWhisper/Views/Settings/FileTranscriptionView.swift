import SwiftUI
import UniformTypeIdentifiers

struct FileTranscriptionView: View {
    @EnvironmentObject private var viewModel: FileTranscriptionViewModel
    @State private var showingFilePicker = false

    var body: some View {
        List {
            Section {
                Button {
                    showingFilePicker = true
                } label: {
                    Label("Add Audio Files", systemImage: "plus.circle")
                }

                ForEach(viewModel.files) { file in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(file.fileName)
                                .font(.body)
                                .lineLimit(1)
                            if let error = file.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else if let result = file.result {
                                Text(result.text.prefix(80))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        switch file.state {
                        case .pending:
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                        case .loading, .transcribing:
                            ProgressView()
                                .controlSize(.small)
                        case .done:
                            Button {
                                viewModel.copyText(for: file)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                        case .error:
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .onDelete { offsets in
                    for offset in offsets.sorted().reversed() {
                        viewModel.removeFile(viewModel.files[offset])
                    }
                }
            }

            if !viewModel.files.isEmpty {
                Section {
                    Button {
                        viewModel.transcribeAll()
                    } label: {
                        Label("Transcribe All", systemImage: "play.fill")
                    }
                    .disabled(!viewModel.canTranscribe)

                    if viewModel.hasResults {
                        Button {
                            viewModel.copyAllText()
                        } label: {
                            Label("Copy All Text", systemImage: "doc.on.doc")
                        }

                        Button("Reset", role: .destructive) {
                            viewModel.reset()
                        }
                    }
                }
            }
        }
        .navigationTitle("File Transcription")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: FileTranscriptionViewModel.allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.addFiles(urls)
            case .failure:
                break
            }
        }
    }
}
