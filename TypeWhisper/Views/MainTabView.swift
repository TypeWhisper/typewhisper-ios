import SwiftUI

struct MainTabView: View {
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
    }
}
