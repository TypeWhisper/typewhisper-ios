import SwiftUI
import UIKit
import AudioToolbox

// MARK: - PopupCoordinator

final class PopupCoordinator: ObservableObject {
    @Published var isActive = false
    @Published var alternatives: [String] = []
    @Published var keyFrame: CGRect = .zero
    @Published var selectedIndex: Int = 0
    @Published var originalChar: String = ""

    func show(alternatives: [String], originalChar: String, keyFrame: CGRect) {
        self.alternatives = alternatives
        self.originalChar = originalChar
        self.keyFrame = keyFrame
        self.selectedIndex = 0
        self.isActive = true
    }

    func updateSelection(dragX: CGFloat, cellWidth: CGFloat, popupOriginX: CGFloat) {
        guard isActive, !alternatives.isEmpty else { return }
        let relativeX = dragX - popupOriginX
        let index = Int(relativeX / cellWidth)
        selectedIndex = max(0, min(index, alternatives.count - 1))
    }

    func dismiss() -> String? {
        guard isActive else { return nil }
        let result = alternatives.indices.contains(selectedIndex) ? alternatives[selectedIndex] : originalChar
        isActive = false
        alternatives = []
        return result
    }
}

// MARK: - LongPressKeyView

struct LongPressKeyView: View {
    let key: String
    let shifted: Bool
    let theme: KeyboardTheme
    let metrics: KeyboardMetrics
    let popupCoordinator: PopupCoordinator
    let onInsert: (String) -> Void

    @State private var isPressed = false
    @State private var holdTimer: Timer?
    @State private var holdFired = false
    @State private var keyFrame: CGRect = .zero

    private var displayChar: String {
        shifted ? key.uppercased() : key.lowercased()
    }

    var body: some View {
        ZStack {
            KeyCapBackground(
                theme: theme,
                metrics: metrics,
                kind: .standard,
                isHighlighted: isPressed
            )

            Text(displayChar)
                .font(metrics.font(for: .standard))
                .foregroundColor(theme.textColor(for: .standard))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        keyFrame = geo.frame(in: .named("keyboard"))
                    }
                    .onChange(of: geo.frame(in: .named("keyboard"))) { _, newFrame in
                        keyFrame = newFrame
                    }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("keyboard"))
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        holdFired = false
                        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                            Task { @MainActor in
                                holdFired = true
                                if let alts = AlternativeCharacters.alternatives(for: key, shifted: shifted) {
                                    popupCoordinator.show(
                                        alternatives: alts,
                                        originalChar: displayChar,
                                        keyFrame: keyFrame
                                    )
                                }
                            }
                        }
                    }
                    if holdFired && popupCoordinator.isActive {
                        let cellWidth: CGFloat = 38
                        let popupWidth = cellWidth * CGFloat(popupCoordinator.alternatives.count)
                        let popupOriginX = popupCoordinator.keyFrame.midX - popupWidth / 2
                        popupCoordinator.updateSelection(
                            dragX: value.location.x,
                            cellWidth: cellWidth,
                            popupOriginX: popupOriginX
                        )
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    holdTimer?.invalidate()
                    holdTimer = nil
                    AudioServicesPlaySystemSound(1104)
                    if holdFired {
                        if let selected = popupCoordinator.dismiss() {
                            onInsert(selected)
                        }
                    } else {
                        onInsert(displayChar)
                    }
                }
        )
    }
}

// MARK: - AlternativeCharsPopup

struct AlternativeCharsPopup: View {
    @ObservedObject var coordinator: PopupCoordinator
    let theme: KeyboardTheme
    let metrics: KeyboardMetrics
    let keyboardWidth: CGFloat

    private let cellWidth: CGFloat = 38
    private let cellHeight: CGFloat = 42
    private let padding: CGFloat = 4

    var body: some View {
        if coordinator.isActive, !coordinator.alternatives.isEmpty {
            let popupWidth = cellWidth * CGFloat(coordinator.alternatives.count) + padding * 2
            let idealX = coordinator.keyFrame.midX - popupWidth / 2
            let clampedX = max(4, min(idealX, keyboardWidth - popupWidth - 4))
            let popupY = coordinator.keyFrame.minY - cellHeight - 8

            HStack(spacing: 0) {
                ForEach(Array(coordinator.alternatives.enumerated()), id: \.offset) { index, char in
                    Text(char)
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: cellWidth, height: cellHeight)
                        .foregroundColor(
                            index == coordinator.selectedIndex
                                ? Color.white
                                : theme.keyText
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(index == coordinator.selectedIndex ? theme.accent : Color.clear)
                        )
                }
            }
            .padding(.horizontal, padding)
            .background(
                RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                    .fill(theme.keyBackground)
                    .shadow(color: theme.keyShadow.opacity(0.35), radius: 6, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                            .stroke(theme.keyBorder, lineWidth: 0.5)
                    )
            )
            .position(x: clampedX + popupWidth / 2, y: popupY + cellHeight / 2)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - RepeatDeleteKeyView

struct RepeatDeleteKeyView: View {
    let theme: KeyboardTheme
    let metrics: KeyboardMetrics
    let onDelete: () -> Void

    @State private var isPressed = false
    @State private var repeatTimer: Timer?
    @State private var deleteCount = 0
    @State private var holdTimer: Timer?

    var body: some View {
        ZStack {
            KeyCapBackground(
                theme: theme,
                metrics: metrics,
                kind: .special,
                isHighlighted: isPressed
            )

            Image(systemName: "delete.left")
                .font(metrics.font(for: .special))
                .foregroundColor(theme.textColor(for: .special))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    deleteCount = 0
                    AudioServicesPlaySystemSound(1155)
                    onDelete()
                    holdTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                        Task { @MainActor in
                            startRepeat(interval: 0.1)
                        }
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    stopTimers()
                }
        )
    }

    private func startRepeat(interval: TimeInterval) {
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                deleteCount += 1
                onDelete()
                if deleteCount == 10 && interval > 0.05 {
                    startRepeat(interval: 0.05)
                }
            }
        }
    }

    private func stopTimers() {
        holdTimer?.invalidate()
        holdTimer = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
        deleteCount = 0
    }
}
