import SwiftUI

struct ModelManagerView: View {
    @EnvironmentObject private var viewModel: ModelManagerViewModel

    private var appleSpeechModels: [ModelInfo] {
        viewModel.models.filter { $0.engineType == .appleSpeech }
    }

    private var whisperModels: [ModelInfo] {
        viewModel.models.filter { $0.engineType == .whisper }
    }

    var body: some View {
        List {
            Section {
                ForEach(appleSpeechModels) { model in
                    ModelRow(model: model, status: viewModel.status(for: model)) {
                        viewModel.downloadModel(model)
                    } onDelete: {
                        viewModel.deleteModel(model)
                    }
                }
            } header: {
                Text("Built-in")
            } footer: {
                Text("Apple's on-device speech recognition. No download required.")
            }

            Section {
                ForEach(whisperModels) { model in
                    ModelRow(model: model, status: viewModel.status(for: model)) {
                        viewModel.downloadModel(model)
                    } onDelete: {
                        viewModel.deleteModel(model)
                    }
                }
            } header: {
                Text("WhisperKit Models")
            } footer: {
                Text("Larger models are more accurate but use more memory and are slower.")
            }
        }
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ModelRow: View {
    let model: ModelInfo
    let status: ModelStatus
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.displayName)
                        .font(.headline)
                    if model.isRecommended {
                        Text("Recommended")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                Text(model.sizeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusView
        }
        .padding(.vertical, 4)
    }

    private var isAppleSpeech: Bool {
        model.engineType == .appleSpeech
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .notDownloaded:
            Button(isAppleSpeech ? "Activate" : "Download", action: onDownload)
                .buttonStyle(.bordered)
                .controlSize(.small)

        case .downloading(let progress, _):
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .frame(width: 80)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        case .loading(let phase):
            VStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text(phase ?? "Loading...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        case .ready:
            Menu {
                Button(isAppleSpeech ? "Deactivate" : "Delete Model", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

        case .error(let message):
            VStack(spacing: 4) {
                Button("Retry", action: onDownload)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }
}
