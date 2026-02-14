import SwiftUI
import UIKit

enum KeyKind {
    case standard
    case special
    case mic
    case micActive
}

struct KeyboardTheme {
    let backgroundTop: Color
    let backgroundBottom: Color
    let keyBackground: Color
    let specialKeyBackground: Color
    let micKeyBackground: Color
    let micKeyActiveBackground: Color
    let keyPressedOverlay: Color
    let keyBorder: Color
    let keyShadow: Color
    let keyText: Color
    let specialKeyText: Color
    let micKeyText: Color
    let bannerBackground: Color
    let statusBackground: Color
    let warning: Color
    let accent: Color
    let levelBar: Color

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }

    func baseColor(for kind: KeyKind) -> Color {
        switch kind {
        case .standard:
            return keyBackground
        case .special:
            return specialKeyBackground
        case .mic:
            return micKeyBackground
        case .micActive:
            return micKeyActiveBackground
        }
    }

    func textColor(for kind: KeyKind) -> Color {
        switch kind {
        case .standard:
            return keyText
        case .special:
            return specialKeyText
        case .mic, .micActive:
            return micKeyText
        }
    }

    static let `default` = KeyboardTheme(
        backgroundTop: KeyboardTheme.dynamicColor(
            light: UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1.0),
            dark: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        ),
        backgroundBottom: KeyboardTheme.dynamicColor(
            light: UIColor(red: 0.88, green: 0.89, blue: 0.92, alpha: 1.0),
            dark: UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        ),
        keyBackground: KeyboardTheme.dynamicColor(
            light: UIColor(white: 0.97, alpha: 1.0),
            dark: UIColor(white: 0.20, alpha: 1.0)
        ),
        specialKeyBackground: KeyboardTheme.dynamicColor(
            light: UIColor(white: 0.86, alpha: 1.0),
            dark: UIColor(white: 0.30, alpha: 1.0)
        ),
        micKeyBackground: Color(uiColor: UIColor(red: 0.00, green: 0.48, blue: 1.0, alpha: 1.0)),
        micKeyActiveBackground: Color(uiColor: UIColor(red: 0.86, green: 0.23, blue: 0.19, alpha: 1.0)),
        keyPressedOverlay: KeyboardTheme.dynamicColor(
            light: UIColor(white: 0.0, alpha: 0.08),
            dark: UIColor(white: 1.0, alpha: 0.12)
        ),
        keyBorder: KeyboardTheme.dynamicColor(
            light: UIColor(white: 0.72, alpha: 1.0),
            dark: UIColor(white: 0.05, alpha: 1.0)
        ),
        keyShadow: KeyboardTheme.dynamicColor(
            light: UIColor(white: 0.0, alpha: 0.18),
            dark: UIColor(white: 0.0, alpha: 0.55)
        ),
        keyText: KeyboardTheme.dynamicColor(
            light: UIColor(white: 0.10, alpha: 1.0),
            dark: UIColor(white: 0.95, alpha: 1.0)
        ),
        specialKeyText: KeyboardTheme.dynamicColor(
            light: UIColor(white: 0.12, alpha: 1.0),
            dark: UIColor(white: 0.95, alpha: 1.0)
        ),
        micKeyText: Color.white,
        bannerBackground: KeyboardTheme.dynamicColor(
            light: UIColor(white: 0.80, alpha: 0.9),
            dark: UIColor(white: 0.18, alpha: 0.9)
        ),
        statusBackground: KeyboardTheme.dynamicColor(
            light: UIColor(white: 0.84, alpha: 0.6),
            dark: UIColor(white: 0.18, alpha: 0.6)
        ),
        warning: Color(uiColor: UIColor(red: 0.89, green: 0.42, blue: 0.24, alpha: 1.0)),
        accent: Color(uiColor: UIColor(red: 0.00, green: 0.48, blue: 1.0, alpha: 1.0)),
        levelBar: Color(uiColor: UIColor(red: 0.00, green: 0.48, blue: 1.0, alpha: 1.0))
    )

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct KeyboardMetrics {
    let keyHeight: CGFloat
    let keySpacing: CGFloat
    let rowSpacing: CGFloat
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let rowInsets: [EdgeInsets]
    let outerHorizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let sectionSpacing: CGFloat
    let topBarHeight: CGFloat
    let keyboardHeight: CGFloat
    let fontSize: CGFloat
    let specialFontSize: CGFloat
    let micFontSize: CGFloat
    let statusFontSize: CGFloat
    let bannerFontSize: CGFloat
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let barMinHeight: CGFloat
    let barMaxHeight: CGFloat

    func rowInset(_ index: Int) -> EdgeInsets {
        if index < rowInsets.count {
            return rowInsets[index]
        }
        return rowInsets.last ?? EdgeInsets()
    }

    func font(for kind: KeyKind) -> Font {
        switch kind {
        case .standard:
            return .system(size: fontSize, weight: .medium)
        case .special:
            return .system(size: specialFontSize, weight: .semibold)
        case .mic, .micActive:
            return .system(size: micFontSize, weight: .bold)
        }
    }

    @MainActor
    static func resolve(for size: CGSize) -> KeyboardMetrics {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let isLandscape = size.width > size.height
        let width = size.width
        let isWidePad = isPad && width >= 900

        var keyHeight: CGFloat = isPad ? (isLandscape ? 44 : 48) : (isLandscape ? 34 : 40)
        var keySpacing: CGFloat = isPad ? 8 : 6
        var rowSpacing: CGFloat = isPad ? 8 : 6
        let cornerRadius: CGFloat = isPad ? 8 : 6
        let borderWidth: CGFloat = isPad ? 0.7 : 0.6
        var outerHorizontalPadding: CGFloat = isPad ? 10 : 6
        let topPadding: CGFloat = isPad ? 6 : 4
        let bottomPadding: CGFloat = isPad ? 10 : 6
        var sectionSpacing: CGFloat = isPad ? 8 : 6
        let topBarHeight: CGFloat = isPad ? 44 : 38
        let fontSize: CGFloat = isPad ? 20 : 17
        let specialFontSize: CGFloat = isPad ? 18 : 15
        let micFontSize: CGFloat = isPad ? 19 : 16
        let statusFontSize: CGFloat = isPad ? 13 : 12
        let bannerFontSize: CGFloat = isPad ? 12 : 11
        let shadowRadius: CGFloat = isPad ? 1.6 : 1.2
        let shadowY: CGFloat = isPad ? 1.2 : 0.8

        if isWidePad {
            keyHeight += 2
            keySpacing += 2
            rowSpacing += 2
            outerHorizontalPadding += 4
            sectionSpacing += 2
        }

        let rowInsets: [EdgeInsets] = [
            EdgeInsets(top: 0, leading: isPad ? 10 : 4, bottom: 0, trailing: isPad ? 10 : 4),
            EdgeInsets(top: 0, leading: isPad ? 30 : 16, bottom: 0, trailing: isPad ? 30 : 16),
            EdgeInsets(top: 0, leading: isPad ? 22 : 22, bottom: 0, trailing: isPad ? 22 : 22),
            EdgeInsets(top: 0, leading: isPad ? 10 : 4, bottom: 0, trailing: isPad ? 10 : 4)
        ]

        let rowsHeight = keyHeight * 4 + rowSpacing * 3
        let keyboardHeight = topPadding + topBarHeight + sectionSpacing + rowsHeight + bottomPadding

        let barMinHeight: CGFloat = isPad ? 6 : 4
        let barMaxHeight: CGFloat = isPad ? 34 : 28

        return KeyboardMetrics(
            keyHeight: keyHeight,
            keySpacing: keySpacing,
            rowSpacing: rowSpacing,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            rowInsets: rowInsets,
            outerHorizontalPadding: outerHorizontalPadding,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
            sectionSpacing: sectionSpacing,
            topBarHeight: topBarHeight,
            keyboardHeight: keyboardHeight,
            fontSize: fontSize,
            specialFontSize: specialFontSize,
            micFontSize: micFontSize,
            statusFontSize: statusFontSize,
            bannerFontSize: bannerFontSize,
            shadowRadius: shadowRadius,
            shadowY: shadowY,
            barMinHeight: barMinHeight,
            barMaxHeight: barMaxHeight
        )
    }
}

struct KeyboardRowLayout: Layout {
    var weights: [CGFloat]
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let height = proposal.height ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }

        let totalWeight = weights.reduce(0, +)
        let availableWidth = max(bounds.width - spacing * CGFloat(subviews.count - 1), 0)
        var x = bounds.minX

        for (index, subview) in subviews.enumerated() {
            let weight = index < weights.count ? weights[index] : 1
            let width = totalWeight > 0 ? availableWidth * weight / totalWeight : 0
            let size = CGSize(width: width, height: bounds.height)
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += width + spacing
        }
    }
}

struct KeyButtonStyle: ButtonStyle {
    let theme: KeyboardTheme
    let metrics: KeyboardMetrics
    let kind: KeyKind
    let isToggled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isHighlighted = configuration.isPressed || isToggled

        return configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
            .background(
                KeyCapBackground(
                    theme: theme,
                    metrics: metrics,
                    kind: kind,
                    isHighlighted: isHighlighted
                )
            )
            .transaction { transaction in
                transaction.animation = nil
            }
    }
}

struct KeyCapLabel<Content: View>: View {
    let theme: KeyboardTheme
    let metrics: KeyboardMetrics
    let kind: KeyKind
    let isHighlighted: Bool
    let font: Font
    let content: Content

    init(
        theme: KeyboardTheme,
        metrics: KeyboardMetrics,
        kind: KeyKind,
        isHighlighted: Bool = false,
        font: Font,
        @ViewBuilder content: () -> Content
    ) {
        self.theme = theme
        self.metrics = metrics
        self.kind = kind
        self.isHighlighted = isHighlighted
        self.font = font
        self.content = content()
    }

    var body: some View {
        ZStack {
            KeyCapBackground(
                theme: theme,
                metrics: metrics,
                kind: kind,
                isHighlighted: isHighlighted
            )

            content
                .font(font)
                .foregroundColor(theme.textColor(for: kind))
                .lineLimit(1)
        }
    }
}

struct KeyCapBackground: View {
    let theme: KeyboardTheme
    let metrics: KeyboardMetrics
    let kind: KeyKind
    let isHighlighted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .fill(theme.baseColor(for: kind))
            .overlay(
                RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                    .fill(theme.keyPressedOverlay)
                    .opacity(isHighlighted ? 1 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                    .stroke(theme.keyBorder, lineWidth: metrics.borderWidth)
            )
            .shadow(
                color: theme.keyShadow.opacity(isHighlighted ? 0.12 : 0.22),
                radius: metrics.shadowRadius,
                x: 0,
                y: metrics.shadowY
            )
    }
}
