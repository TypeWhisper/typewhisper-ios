import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var homeVM: HomeViewModel
    @EnvironmentObject private var modelManager: ModelManagerViewModel

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section("Statistics") {
                LabeledContent("Total Recordings", value: "\(homeVM.recordingsCount)")
                LabeledContent("Total Words", value: "\(homeVM.wordsCount)")
                LabeledContent("Time Saved", value: homeVM.timeSaved)
            }

            Section("About") {
                LabeledContent("Version", value: versionString)
                if let modelId = modelManager.selectedModelId,
                   let model = ModelInfo.allModels.first(where: { $0.id == modelId }) {
                    LabeledContent("Engine", value: model.engineType.displayName)
                    LabeledContent("Model", value: model.displayName)
                } else {
                    LabeledContent("Engine", value: "No model loaded")
                }
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { homeVM.refresh() }
    }
}
