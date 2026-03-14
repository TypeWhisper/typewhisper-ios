import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var flowSessionManager: FlowSessionManager

    var body: some View {
        VStack(spacing: 0) {
            if flowSessionManager.openedFromKeyboard {
                KeyboardReturnBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

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
        }
        .animation(.easeInOut(duration: 0.25), value: flowSessionManager.openedFromKeyboard)
        .sheet(isPresented: $flowSessionManager.showFileTranscriptionSheet) {
            NavigationStack {
                FileTranscriptionView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { flowSessionManager.showFileTranscriptionSheet = false }
                        }
                    }
            }
        }
    }
}

private struct KeyboardReturnBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
            Text("Flow Active")
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Image(systemName: "keyboard")
                .font(.system(size: 11))
            Text("Switch back to type")
                .font(.system(size: 12, weight: .regular))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background {
            Color.blue.opacity(0.85).ignoresSafeArea(edges: .top)
        }
    }
}
