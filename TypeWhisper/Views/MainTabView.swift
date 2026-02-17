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
                KeyboardReturnBanner {
                    flowSessionManager.openedFromKeyboard = false
                    UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: flowSessionManager.openedFromKeyboard)
    }
}

private struct KeyboardReturnBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Zurück zur Tastatur")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text("Flow aktiv")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background {
            Color.blue.ignoresSafeArea(edges: .top)
        }
    }
}
