import SwiftUI

struct SnippetsSettingsView: View {
    @EnvironmentObject private var viewModel: SnippetsViewModel

    @State private var showingAddSheet = false
    @State private var newTrigger = ""
    @State private var newReplacement = ""
    @State private var newCaseSensitive = false

    var body: some View {
        List {
            Section {
                ForEach(viewModel.snippets) { snippet in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(snippet.trigger)
                                .font(.body.monospaced())
                            Text(snippet.replacement)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { snippet.isEnabled },
                            set: { _ in viewModel.toggleSnippet(snippet) }
                        ))
                        .labelsHidden()
                    }
                }
                .onDelete { offsets in
                    let snippets = offsets.map { viewModel.snippets[$0] }
                    for snippet in snippets {
                        viewModel.deleteSnippet(snippet)
                    }
                }
            } header: {
                Text("\(viewModel.enabledCount) active")
            } footer: {
                Text("Snippets replace trigger text in transcriptions. Use {{DATE}}, {{TIME}}, {{CLIPBOARD}} as placeholders.")
            }
        }
        .navigationTitle("Snippets")
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
                    TextField("Trigger", text: $newTrigger)
                    TextField("Replacement", text: $newReplacement, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Case sensitive", isOn: $newCaseSensitive)
                }
                .navigationTitle("Add Snippet")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAddSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            viewModel.addSnippet(
                                trigger: newTrigger,
                                replacement: newReplacement,
                                caseSensitive: newCaseSensitive
                            )
                            newTrigger = ""
                            newReplacement = ""
                            showingAddSheet = false
                        }
                        .disabled(newTrigger.isEmpty || newReplacement.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
