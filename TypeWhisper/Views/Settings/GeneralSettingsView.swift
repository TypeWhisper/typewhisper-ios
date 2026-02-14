import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var homeVM: HomeViewModel

    var body: some View {
        List {
            Section("Statistics") {
                LabeledContent("Total Recordings", value: "\(homeVM.recordingsCount)")
                LabeledContent("Total Words", value: "\(homeVM.wordsCount)")
                LabeledContent("Time Saved", value: homeVM.timeSaved)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Engine", value: "WhisperKit")
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }
}
