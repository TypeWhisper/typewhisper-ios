import SwiftUI

struct MicrophoneButton: View {
    let isRecording: Bool
    let audioLevel: Float
    let action: () -> Void

    private var ringScale: CGFloat {
        isRecording ? 1.0 + CGFloat(audioLevel) * 0.3 : 1.0
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Animated ring
                Circle()
                    .stroke(isRecording ? Color.red.opacity(0.3) : Color.accentColor.opacity(0.2), lineWidth: 4)
                    .frame(width: 100, height: 100)
                    .scaleEffect(ringScale)
                    .animation(.easeOut(duration: 0.1), value: audioLevel)

                // Main circle
                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: 80, height: 80)

                // Icon
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: isRecording)
    }
}
