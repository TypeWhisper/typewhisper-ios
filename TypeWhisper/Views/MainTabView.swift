import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var flowSessionManager: FlowSessionManager

    var body: some View {
        TabView {
            Tab("Record", systemImage: "mic.fill") {
                RecordView()
            }

            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if flowSessionManager.openedFromKeyboard {
                KeyboardReturnBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: flowSessionManager.openedFromKeyboard)
    }
}

private struct KeyboardReturnBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.system(size: 14, weight: .semibold))
            Text("Switch back to continue typing")
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Text("Flow Active")
                .font(.system(size: 12, weight: .regular))
                .opacity(0.7)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Color.blue.ignoresSafeArea(edges: .top)
        }
    }
}
