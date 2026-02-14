import SwiftUI

struct RecordView: View {
    @EnvironmentObject private var viewModel: RecordingViewModel
    @EnvironmentObject private var modelManager: ModelManagerViewModel
    @State private var showModelManager = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Status / Partial Text
                statusSection

                Spacer()

                // Microphone Button
                MicrophoneButton(
                    isRecording: viewModel.state == .recording,
                    audioLevel: viewModel.audioLevel
                ) {
                    viewModel.toggleRecording()
                }
                .padding(.bottom, 8)

                // Recording duration
                if viewModel.state == .recording {
                    Text(formatDuration(viewModel.recordingDuration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                // Result Card
                if case .done(let text) = viewModel.state {
                    ResultCardView(text: text) {
                        viewModel.dismissResult()
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("TypeWhisper")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    modelStatusIndicator
                }
            }
            .navigationDestination(isPresented: $showModelManager) {
                ModelManagerView()
            }
            .overlay {
                if viewModel.state == .processing {
                    processingOverlay
                }
            }
            .alert("Microphone Access", isPresented: .constant(viewModel.needsMicPermission && viewModel.state == .idle)) {
                Button("Grant Access") {
                    viewModel.requestMicPermission()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("TypeWhisper needs microphone access to transcribe your speech.")
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if viewModel.state == .processing {
            EmptyView()
        } else if viewModel.state == .recording, !viewModel.partialText.isEmpty {
            ScrollView {
                Text(viewModel.partialText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxHeight: 200)
        } else if viewModel.state == .recording {
            WaveformView(audioLevel: viewModel.audioLevel)
                .frame(height: 60)
                .padding(.horizontal, 40)
        } else if modelManager.isLoadingModel {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading model...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        } else if !modelManager.isModelReady {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No model loaded")
                    .font(.headline)
                Text("Go to Settings → Models to download a speech recognition model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else if case .error(let message) = viewModel.state {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var modelStatusIndicator: some View {
        if let name = modelManager.activeModelName {
            Button {
                showModelManager = true
            } label: {
                Text(name)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.fill.tertiary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var processingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Transcribing...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: -80)
        .background(.black.opacity(0.6))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}
