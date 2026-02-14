import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    private let barCount = 20

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.tint)
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.1), value: audioLevel)
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let center = Double(barCount) / 2.0
        let distance = abs(Double(index) - center) / center
        let baseHeight: CGFloat = 4
        let maxAdditional: CGFloat = 50
        let level = CGFloat(audioLevel)
        let variation = sin(Double(index) * 0.8 + Double(audioLevel) * 10) * 0.3 + 0.7
        return baseHeight + maxAdditional * level * (1 - distance * 0.5) * variation
    }
}
