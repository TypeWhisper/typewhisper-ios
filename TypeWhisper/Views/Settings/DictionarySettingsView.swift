import SwiftUI
import UniformTypeIdentifiers

struct DictionarySettingsView: View {
    @EnvironmentObject private var viewModel: DictionaryViewModel

    @State private var showingAddSheet = false
    @State private var newOriginal = ""
    @State private var newReplacement = ""
    @State private var newType: DictionaryEntryType = .term
    @State private var newCaseSensitive = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: DictionaryExportDocument?
    @State private var importMessage: String?
    @State private var error: String?
    @State private var showingAlert = false

    var body: some View {
        List {
            Section {
                ForEach(viewModel.filteredEntries) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.displayText)
                                .font(.body)
                            Text(entry.type.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { entry.isEnabled },
                            set: { _ in viewModel.toggleEntry(entry) }
                        ))
                        .labelsHidden()
                    }
                }
                .onDelete { offsets in
                    let entries = offsets.map { viewModel.filteredEntries[$0] }
                    for entry in entries {
                        viewModel.deleteEntry(entry)
                    }
                }
            } header: {
                HStack {
                    Text("\(viewModel.termsCount) Terms · \(viewModel.correctionsCount) Corrections")
                }
            }
        }
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .json, defaultFilename: "dictionary-export.json") { result in
            if case .failure(let err) = result {
                error = err.localizedDescription
                showingAlert = true
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    let importResult = try viewModel.importDictionary(from: url)
                    if importResult.skipped > 0 {
                        importMessage = "\(importResult.imported) entries imported, \(importResult.skipped) duplicates skipped."
                    } else {
                        importMessage = "\(importResult.imported) entries imported."
                    }
                } catch {
                    self.error = error.localizedDescription
                }
                showingAlert = true
            case .failure(let err):
                error = err.localizedDescription
                showingAlert = true
            }
        }
        .alert("Dictionary Import", isPresented: $showingAlert) {
            Button("OK") {
                importMessage = nil
                error = nil
            }
        } message: {
            Text(importMessage ?? error ?? "")
        }
        .searchable(text: $viewModel.searchQuery, prompt: "Search dictionary")
        .navigationTitle("Dictionary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        exportDocument = viewModel.exportDocument()
                        showingExporter = true
                    } label: {
                        Label(String(localized: "Export..."), systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.entries.isEmpty)

                    Button {
                        showingImporter = true
                    } label: {
                        Label(String(localized: "Import..."), systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                Form {
                    Picker("Type", selection: $newType) {
                        ForEach(DictionaryEntryType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    TextField("Original text", text: $newOriginal)

                    if newType == .correction {
                        TextField("Replacement", text: $newReplacement)
                    }

                    Toggle("Case sensitive", isOn: $newCaseSensitive)
                }
                .navigationTitle("Add Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAddSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            viewModel.addEntry(
                                type: newType,
                                original: newOriginal,
                                replacement: newType == .correction ? newReplacement : nil,
                                caseSensitive: newCaseSensitive
                            )
                            newOriginal = ""
                            newReplacement = ""
                            showingAddSheet = false
                        }
                        .disabled(newOriginal.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
