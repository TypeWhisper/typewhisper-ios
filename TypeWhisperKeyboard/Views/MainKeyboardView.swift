import SwiftUI
import UIKit
import AudioToolbox

struct MainKeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let textDocumentProxy: UITextDocumentProxy
    let hasFullAccessProvider: () -> Bool
    let onSwitchKeyboard: () -> Void
    let onOpenApp: () -> Void
    let metrics: KeyboardMetrics
    let theme: KeyboardTheme
    @StateObject private var popupCoordinator = PopupCoordinator()
    @State private var keyboardMode: KeyboardMode = .letters

    private enum KeyboardMode {
        case letters, numbers, symbols
    }

    private let layoutLanguage = KeyboardLanguage.defaultCode

    private struct KeyboardLayout {
        let row1: [String]
        let row2: [String]
        let row3Letters: [String]
        let spaceLabel: String
    }

    private enum KeyboardLanguage {
        static let supported: [String] = ["DE", "EN", "ES", "FR", "IT"]

        static var defaultCode: String {
            let code = Locale.current.language.languageCode?.identifier.uppercased() ?? "EN"
            return supported.contains(code) ? code : "EN"
        }
    }

    private var layout: KeyboardLayout {
        switch layoutLanguage {
        case "DE":
            return KeyboardLayout(
                row1: ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p", "ü"],
                row2: ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ö", "ä"],
                row3Letters: ["y", "x", "c", "v", "b", "n", "m", "ß"],
                spaceLabel: "Leertaste"
            )
        case "ES":
            return KeyboardLayout(
                row1: ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                row2: ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ñ"],
                row3Letters: ["z", "x", "c", "v", "b", "n", "m"],
                spaceLabel: "Espacio"
            )
        case "FR":
            return KeyboardLayout(
                row1: ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
                row2: ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
                row3Letters: ["w", "x", "c", "v", "b", "n"],
                spaceLabel: "Espace"
            )
        case "IT":
            return KeyboardLayout(
                row1: ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                row2: ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                row3Letters: ["z", "x", "c", "v", "b", "n", "m"],
                spaceLabel: "Spazio"
            )
        case "EN":
            return KeyboardLayout(
                row1: ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                row2: ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                row3Letters: ["z", "x", "c", "v", "b", "n", "m"],
                spaceLabel: "Space"
            )
        default:
            return KeyboardLayout(
                row1: ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                row2: ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                row3Letters: ["z", "x", "c", "v", "b", "n", "m"],
                spaceLabel: "Space"
            )
        }
    }

    var body: some View {
        GeometryReader { outerGeo in
            ZStack(alignment: .top) {
                theme.backgroundGradient

                VStack(spacing: metrics.sectionSpacing) {
                    if !viewModel.isRecording {
                        if viewModel.isProcessing {
                            statusBar
                        } else if !viewModel.availableProfiles.isEmpty {
                            ProfileSelectorView(
                                profiles: viewModel.availableProfiles,
                                selectedProfileId: viewModel.selectedProfileId,
                                onSelect: { viewModel.selectProfile($0) },
                                onDeselect: { viewModel.deselectProfile() },
                                theme: theme,
                                metrics: metrics
                            )
                            .padding(.horizontal, metrics.outerHorizontalPadding)
                        }
                    }
                    keyboardRows
                }
                .padding(.top, metrics.topPadding)
                .padding(.bottom, metrics.bottomPadding)

                if let bannerMessage = viewModel.bannerMessage {
                    HintBanner(
                        message: bannerMessage,
                        actionTitle: viewModel.bannerActionTitle,
                        linkURL: viewModel.bannerOpensSettings
                            ? URL(string: "app-settings:")
                            : URL(string: "typewhisper://startflow?duration=300"),
                        theme: theme,
                        metrics: metrics
                    )
                    .padding(.horizontal, metrics.outerHorizontalPadding)
                    .padding(.top, metrics.topPadding)
                }

                AlternativeCharsPopup(
                    coordinator: popupCoordinator,
                    theme: theme,
                    metrics: metrics,
                    keyboardWidth: outerGeo.size.width
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: "keyboard")
        }
    }

    private var row1Keys: [KeyboardKey] {
        layout.row1.map { KeyboardKey(type: .letter, label: $0) }
    }

    private var row2Keys: [KeyboardKey] {
        layout.row2.map { KeyboardKey(type: .letter, label: $0) }
    }

    private var row3Keys: [KeyboardKey] {
        var keys: [KeyboardKey] = []
        keys.append(KeyboardKey(type: .shift, label: "shift", weight: 1.4))
        for label in layout.row3Letters {
            keys.append(KeyboardKey(type: .letter, label: label))
        }
        keys.append(KeyboardKey(type: .delete, label: "delete", weight: 1.4))
        return keys
    }

    // MARK: - Number layout

    private var numberRow1Keys: [KeyboardKey] {
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
            .map { KeyboardKey(type: .letter, label: $0) }
    }

    private var numberRow2Keys: [KeyboardKey] {
        ["-", "/", ":", ";", "(", ")", "€", "&", "@", "\""]
            .map { KeyboardKey(type: .letter, label: $0) }
    }

    private var numberRow3Keys: [KeyboardKey] {
        var keys: [KeyboardKey] = []
        keys.append(KeyboardKey(type: .symbolToggle, label: "#+=", weight: 1.4))
        for label in [".", ",", "?", "!", "'"] {
            keys.append(KeyboardKey(type: .letter, label: label))
        }
        keys.append(KeyboardKey(type: .delete, label: "delete", weight: 1.4))
        return keys
    }

    // MARK: - Symbol layout

    private var symbolRow1Keys: [KeyboardKey] {
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
            .map { KeyboardKey(type: .letter, label: $0) }
    }

    private var symbolRow2Keys: [KeyboardKey] {
        ["_", "\\", "|", "~", "<", ">", "$", "£", "¥", "•"]
            .map { KeyboardKey(type: .letter, label: $0) }
    }

    private var symbolRow3Keys: [KeyboardKey] {
        var keys: [KeyboardKey] = []
        keys.append(KeyboardKey(type: .numberToggle, label: "123", weight: 1.4))
        for label in [".", ",", "?", "!", "'"] {
            keys.append(KeyboardKey(type: .letter, label: label))
        }
        keys.append(KeyboardKey(type: .delete, label: "delete", weight: 1.4))
        return keys
    }

    private var row4Keys: [KeyboardKey] {
        let toggleLabel = keyboardMode == .letters ? "123" : "ABC"
        return [
            KeyboardKey(type: .numberToggle, label: toggleLabel, weight: 1.2),
            KeyboardKey(type: .globe, label: "globe", weight: 0.8),
            KeyboardKey(type: .mic, label: "mic", weight: 1.2),
            KeyboardKey(type: .space, label: layout.spaceLabel, weight: 4.3),
            KeyboardKey(type: .returnKey, label: "return", weight: 1.1)
        ]
    }

    private var statusBar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .fill(theme.statusBackground)

            if viewModel.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.keyText))
                        .scaleEffect(0.8)
                    Text(L10n.transcriptionProcessing)
                        .font(.system(size: metrics.statusFontSize, weight: .medium))
                        .foregroundColor(theme.keyText.opacity(0.85))
                }
            } else {
                Color.clear
            }
        }
        .frame(height: metrics.topBarHeight)
        .padding(.horizontal, metrics.outerHorizontalPadding)
    }

    private var keyboardRows: some View {
        Group {
            if viewModel.isRecording {
                recordingOverlay
            } else {
                normalKeyboardRows
            }
        }
        .padding(.horizontal, metrics.outerHorizontalPadding)
    }

    private var normalKeyboardRows: some View {
        VStack(spacing: metrics.rowSpacing) {
            switch keyboardMode {
            case .letters:
                KeyboardRow(keys: row1Keys, metrics: metrics, rowInsets: metrics.rowInset(0)) { key in
                    letterKeyView(key: key)
                }
                KeyboardRow(keys: row2Keys, metrics: metrics, rowInsets: metrics.rowInset(1)) { key in
                    letterKeyView(key: key)
                }
                KeyboardRow(keys: row3Keys, metrics: metrics, rowInsets: metrics.rowInset(2)) { key in
                    specialKeyView(key: key)
                }
            case .numbers:
                KeyboardRow(keys: numberRow1Keys, metrics: metrics, rowInsets: metrics.rowInset(0)) { key in
                    charKeyView(key: key)
                }
                KeyboardRow(keys: numberRow2Keys, metrics: metrics, rowInsets: metrics.rowInset(1)) { key in
                    charKeyView(key: key)
                }
                KeyboardRow(keys: numberRow3Keys, metrics: metrics, rowInsets: metrics.rowInset(2)) { key in
                    modeRow3View(key: key)
                }
            case .symbols:
                KeyboardRow(keys: symbolRow1Keys, metrics: metrics, rowInsets: metrics.rowInset(0)) { key in
                    charKeyView(key: key)
                }
                KeyboardRow(keys: symbolRow2Keys, metrics: metrics, rowInsets: metrics.rowInset(1)) { key in
                    charKeyView(key: key)
                }
                KeyboardRow(keys: symbolRow3Keys, metrics: metrics, rowInsets: metrics.rowInset(2)) { key in
                    modeRow3View(key: key)
                }
            }
            KeyboardRow(keys: row4Keys, metrics: metrics, rowInsets: metrics.rowInset(3)) { key in
                bottomRowKeyView(key: key)
            }
        }
    }

    private var averageAudioLevel: CGFloat {
        guard !viewModel.audioLevels.isEmpty else { return 0 }
        let sum = viewModel.audioLevels.reduce(Float(0), +)
        return CGFloat(sum / Float(viewModel.audioLevels.count))
    }

    private var recordingOverlay: some View {
        VStack(spacing: metrics.rowSpacing) {
            VStack(spacing: 6) {
                RippleRingsView(
                    audioLevel: averageAudioLevel,
                    color: theme.levelBar
                )
                .frame(width: 90, height: 90)

                CenterWaveformView(
                    levels: viewModel.audioLevels,
                    barColor: theme.levelBar
                )
                .frame(height: 36)
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: .infinity)

            HStack {
                Button {
                    viewModel.cancelRecording()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.keyText.opacity(0.7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(KeyButtonStyle(theme: theme, metrics: metrics, kind: .special, isToggled: false))

                Button {
                    viewModel.handleMicTap(hasFullAccess: hasFullAccessProvider())
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                        Text("Stop")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(KeyButtonStyle(theme: theme, metrics: metrics, kind: .micActive, isToggled: false))
            }
            .frame(height: metrics.keyHeight)
        }
    }

    @ViewBuilder
    private func letterKeyView(key: KeyboardKey) -> some View {
        LongPressKeyView(
            key: key.label,
            shifted: viewModel.shiftEnabled,
            theme: theme,
            metrics: metrics,
            popupCoordinator: popupCoordinator,
            onInsert: { char in
                textDocumentProxy.insertText(char)
                if viewModel.shiftEnabled {
                    viewModel.shiftEnabled = false
                }
            }
        )
    }

    @ViewBuilder
    private func charKeyView(key: KeyboardKey) -> some View {
        keyButton(kind: .standard, isToggled: false, action: {
            textDocumentProxy.insertText(key.label)
        }) {
            Text(key.label)
                .font(metrics.font(for: .standard))
                .foregroundColor(theme.textColor(for: .standard))
        }
    }

    @ViewBuilder
    private func modeRow3View(key: KeyboardKey) -> some View {
        switch key.type {
        case .symbolToggle:
            keyButton(kind: .special, isToggled: false, action: {
                keyboardMode = .symbols
            }) {
                Text(key.label)
                    .font(metrics.font(for: .special))
                    .foregroundColor(theme.textColor(for: .special))
            }
        case .numberToggle:
            keyButton(kind: .special, isToggled: false, action: {
                keyboardMode = .numbers
            }) {
                Text(key.label)
                    .font(metrics.font(for: .special))
                    .foregroundColor(theme.textColor(for: .special))
            }
        case .delete:
            RepeatDeleteKeyView(
                theme: theme,
                metrics: metrics,
                onDelete: { textDocumentProxy.deleteBackward() }
            )
        case .letter:
            charKeyView(key: key)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func specialKeyView(key: KeyboardKey) -> some View {
        switch key.type {
        case .letter:
            letterKeyView(key: key)
        case .shift:
            keyButton(kind: .special, isToggled: viewModel.shiftEnabled, action: {
                viewModel.toggleShift()
            }) {
                Text("⇧")
                    .font(metrics.font(for: .special))
                    .foregroundColor(theme.textColor(for: .special))
            }
        case .delete:
            RepeatDeleteKeyView(
                theme: theme,
                metrics: metrics,
                onDelete: { textDocumentProxy.deleteBackward() }
            )
        default:
            KeyCapLabel(
                theme: theme,
                metrics: metrics,
                kind: .special,
                font: metrics.font(for: .special)
            ) {
                Text("")
            }
        }
    }

    @ViewBuilder
    private func bottomRowKeyView(key: KeyboardKey) -> some View {
        switch key.type {
        case .numberToggle:
            keyButton(kind: .special, isToggled: false, action: {
                keyboardMode = keyboardMode == .letters ? .numbers : .letters
            }) {
                Text(key.label)
                    .font(metrics.font(for: .special))
                    .foregroundColor(theme.textColor(for: .special))
            }
        case .globe:
            keyButton(kind: .special, isToggled: false, action: onSwitchKeyboard) {
                Image(systemName: "globe")
                    .font(metrics.font(for: .special))
                    .foregroundColor(theme.textColor(for: .special))
            }
        case .mic:
            let isActive = viewModel.isRecording || viewModel.isPendingStart
            MicKeyView(
                isActive: isActive,
                kind: isActive ? .micActive : .mic,
                theme: theme, metrics: metrics,
                onTap: { viewModel.handleMicTap(hasFullAccess: hasFullAccessProvider()) },
                onHoldStart: { viewModel.handleMicHoldStart(hasFullAccess: hasFullAccessProvider()) },
                onHoldEnd: { viewModel.handleMicHoldEnd() }
            )
        case .space:
            keyButton(kind: .standard, isToggled: false, action: {
                viewModel.handleSpaceTap()
                textDocumentProxy.insertText(" ")
            }) {
                Text(key.label)
                    .font(metrics.font(for: .standard))
                    .foregroundColor(theme.textColor(for: .standard))
            }
        case .returnKey:
            keyButton(kind: .special, isToggled: false, action: {
                textDocumentProxy.insertText("\n")
            }) {
                Image(systemName: "return")
                    .font(metrics.font(for: .special))
                    .foregroundColor(theme.textColor(for: .special))
            }
        default:
            KeyCapLabel(
                theme: theme,
                metrics: metrics,
                kind: .special,
                font: metrics.font(for: .special)
            ) {
                Text("")
            }
        }
    }

    private func keyButton<Label: View>(
        kind: KeyKind,
        isToggled: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            AudioServicesPlaySystemSound(kind == .special ? 1156 : 1104)
            action()
        } label: {
            label()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(KeyButtonStyle(theme: theme, metrics: metrics, kind: kind, isToggled: isToggled))
    }
}

struct KeyboardRow<Content: View>: View {
    let keys: [KeyboardKey]
    let metrics: KeyboardMetrics
    let rowInsets: EdgeInsets
    let content: (KeyboardKey) -> Content

    var body: some View {
        KeyboardRowLayout(weights: keys.map { $0.weight }, spacing: metrics.keySpacing) {
            ForEach(keys) { key in
                content(key)
            }
        }
        .frame(height: metrics.keyHeight)
        .padding(rowInsets)
    }
}

struct HintBanner: View {
    let message: String
    let actionTitle: String
    var linkURL: URL? = nil
    var onAction: (() -> Void)? = nil
    let theme: KeyboardTheme
    let metrics: KeyboardMetrics

    private var actionLabel: some View {
        Text(actionTitle)
            .font(.system(size: metrics.bannerFontSize, weight: .semibold))
            .foregroundColor(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius))
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(theme.warning)
            Text(message)
                .font(.system(size: metrics.bannerFontSize, weight: .medium))
                .foregroundColor(theme.keyText.opacity(0.9))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer()
            if let url = linkURL {
                Link(destination: url) { actionLabel }
            } else if let onAction {
                Button(action: onAction) { actionLabel }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius))
    }
}

struct CenterWaveformView: View {
    let levels: [Float]
    let barColor: Color

    private let noiseFloor: CGFloat = 0.02
    private let minBarHeight: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let barCount = max(levels.count, 24)
            let spacing: CGFloat = 2
            let barWidth = (geometry.size.width - CGFloat(barCount - 1) * spacing) / CGFloat(barCount)
            let maxAmplitude = geometry.size.height * 0.45

            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let barHeight: CGFloat = {
                        let raw = index < levels.count ? CGFloat(levels[index]) : 0
                        let gated = max(raw - noiseFloor, 0) / (1.0 - noiseFloor)
                        let shaped = CGFloat(pow(Double(gated), 0.8))
                        let value = min(shaped, 1.0)
                        return minBarHeight + value * maxAmplitude * 2
                    }()

                    Capsule()
                        .fill(barColor.opacity(0.75))
                        .frame(width: max(barWidth, 2), height: barHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct RippleRingsView: View {
    let audioLevel: CGFloat
    let color: Color
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(animate ? 1.0 : 0.3)
                    .opacity(animate ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.5),
                        value: animate
                    )
            }

            Circle()
                .fill(color.opacity(0.15))
                .scaleEffect(0.3 + audioLevel * 0.5)
                .animation(.easeOut(duration: 0.1), value: audioLevel)

            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
        }
        .onAppear { animate = true }
    }
}

private struct MicKeyView: View {
    let isActive: Bool
    let kind: KeyKind
    let theme: KeyboardTheme
    let metrics: KeyboardMetrics
    let onTap: () -> Void
    let onHoldStart: () -> Void
    let onHoldEnd: () -> Void

    @State private var isPressed = false
    @State private var holdTimer: Timer?
    @State private var holdFired = false

    var body: some View {
        ZStack {
            KeyCapBackground(
                theme: theme,
                metrics: metrics,
                kind: kind,
                isHighlighted: isPressed
            )

            Image(systemName: isActive ? "stop.fill" : "waveform")
                .font(metrics.font(for: .mic))
                .foregroundColor(theme.textColor(for: kind))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    holdFired = false
                    holdTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                        Task { @MainActor in
                            holdFired = true
                            onHoldStart()
                        }
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    holdTimer?.invalidate()
                    holdTimer = nil
                    if holdFired {
                        onHoldEnd()
                    } else {
                        onTap()
                    }
                }
        )
    }
}
