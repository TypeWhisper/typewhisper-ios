import SwiftUI

struct DictionarySettingsView: View {
    @EnvironmentObject private var viewModel: DictionaryViewModel

    @State private var showingAddSheet = false
    @State private var newOriginal = ""
    @State private var newReplacement = ""
    @State private var newType: DictionaryEntryType = .term
    @State private var newCaseSensitive = false

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
        .searchable(text: $viewModel.searchQuery, prompt: "Search dictionary")
        .navigationTitle("Dictionary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
