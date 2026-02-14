import SwiftUI

struct ProfileSelectorView: View {
    let profiles: [KeyboardProfileDTO]
    let selectedProfileId: UUID?
    let onSelect: (KeyboardProfileDTO) -> Void
    let onDeselect: () -> Void
    let theme: KeyboardTheme
    let metrics: KeyboardMetrics

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pillButton(
                    label: "Standard",
                    isSelected: selectedProfileId == nil
                ) {
                    onDeselect()
                }

                ForEach(profiles) { profile in
                    pillButton(
                        label: profile.name,
                        isSelected: selectedProfileId == profile.id
                    ) {
                        onSelect(profile)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: metrics.topBarHeight)
    }

    private func pillButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: metrics.statusFontSize, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundColor(isSelected ? .white : theme.keyText.opacity(0.85))
                .background(
                    Capsule()
                        .fill(isSelected ? theme.accent : theme.specialKeyBackground)
                )
        }
        .buttonStyle(.plain)
    }
}
