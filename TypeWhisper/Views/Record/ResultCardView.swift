import SwiftUI

struct ResultCardView: View {
    let text: String
    let onDismiss: () -> Void

    @State private var showCopiedFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Transcription", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Text(text)
                .font(.body)
                .textSelection(.enabled)

            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = text
                    showCopiedFeedback = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        showCopiedFeedback = false
                    }
                } label: {
                    Label(showCopiedFeedback ? "Copied!" : "Copy", systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                ShareLink(item: text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
