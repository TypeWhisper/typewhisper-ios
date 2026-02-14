import Foundation
import Combine

@MainActor
final class ModelManagerService: ObservableObject {
    @Published private(set) var modelStatuses: [String: ModelStatus] = [:]
    @Published private(set) var selectedEngine: EngineType = .whisper
    @Published private(set) var selectedModelId: String?
    @Published private(set) var activeEngine: (any TranscriptionEngine)?
    @Published private(set) var isLoadingModel = false

    private let whisperEngine = WhisperEngine()
    private let appleSpeechEngine = AppleSpeechEngine()

    private let modelKey = "selectedModelId"
    private let loadedModelsKey = "loadedModelIds"

    init() {
        self.selectedModelId = UserDefaults.standard.string(forKey: modelKey)

        for model in ModelInfo.allModels {
            modelStatuses[model.id] = .notDownloaded
        }
    }

    var currentEngine: (any TranscriptionEngine)? {
        activeEngine
    }

    var isEngineLoaded: Bool {
        activeEngine != nil
    }

    func engine(for type: EngineType) -> any TranscriptionEngine {
        switch type {
        case .whisper: return whisperEngine
        case .appleSpeech: return appleSpeechEngine
        }
    }

    func selectModel(_ modelId: String) {
        selectedModelId = modelId
        UserDefaults.standard.set(modelId, forKey: modelKey)
    }

    func downloadAndLoadModel(_ model: ModelInfo) async {
        let engine = engine(for: model.engineType)

        if model.engineType == .appleSpeech {
            modelStatuses[model.id] = .loading(phase: "Activating...")
            do {
                try await engine.loadModel(model) { _, _ in }
                modelStatuses[model.id] = .ready
                activeEngine = engine
                selectModel(model.id)
                addToLoadedModels(model.id)
            } catch {
                modelStatuses[model.id] = .error(error.localizedDescription)
            }
            return
        }

        modelStatuses[model.id] = .downloading(progress: 0)

        if let whisperEngine = engine as? WhisperEngine {
            whisperEngine.onPhaseChange = { [weak self] phase in
                Task { @MainActor [weak self] in
                    guard self?.modelStatuses[model.id] != .ready else { return }
                    self?.modelStatuses[model.id] = .loading(phase: phase)
                }
            }
        }

        do {
            try await engine.loadModel(model) { [weak self] progress, speed in
                Task { @MainActor [weak self] in
                    guard self?.modelStatuses[model.id] != .ready else { return }
                    if progress >= 0.80 {
                        self?.modelStatuses[model.id] = .loading()
                    } else {
                        self?.modelStatuses[model.id] = .downloading(progress: progress, bytesPerSecond: speed)
                    }
                }
            }

            modelStatuses[model.id] = .ready
            (engine as? WhisperEngine)?.onPhaseChange = nil
            activeEngine = engine
            selectModel(model.id)
            addToLoadedModels(model.id)
        } catch {
            (engine as? WhisperEngine)?.onPhaseChange = nil
            modelStatuses[model.id] = .error(error.localizedDescription)
        }
    }

    func loadAllSavedModels() async {
        var modelIds = UserDefaults.standard.stringArray(forKey: loadedModelsKey) ?? []

        if modelIds.isEmpty, let selectedId = selectedModelId {
            modelIds = [selectedId]
            UserDefaults.standard.set(modelIds, forKey: loadedModelsKey)
        }

        let modelsToLoad = modelIds.compactMap { id in
            ModelInfo.allModels.first(where: { $0.id == id })
        }

        guard !modelsToLoad.isEmpty else { return }

        isLoadingModel = true
        for model in modelsToLoad {
            await loadSingleModel(model)
        }
        isLoadingModel = false

        if let selectedId = selectedModelId,
           let selectedModel = ModelInfo.allModels.first(where: { $0.id == selectedId }) {
            let eng = engine(for: selectedModel.engineType)
            if eng.isModelLoaded {
                activeEngine = eng
            }
        }
    }

    private func loadSingleModel(_ model: ModelInfo) async {
        let engine = engine(for: model.engineType)

        if engine.isModelLoaded {
            modelStatuses[model.id] = .ready
            return
        }

        modelStatuses[model.id] = .downloading(progress: 0)

        if let whisperEngine = engine as? WhisperEngine {
            whisperEngine.onPhaseChange = { [weak self] phase in
                Task { @MainActor [weak self] in
                    guard self?.modelStatuses[model.id] != .ready else { return }
                    self?.modelStatuses[model.id] = .loading(phase: phase)
                }
            }
        }

        do {
            try await engine.loadModel(model) { [weak self] progress, speed in
                Task { @MainActor [weak self] in
                    guard self?.modelStatuses[model.id] != .ready else { return }
                    if progress >= 0.80 {
                        self?.modelStatuses[model.id] = .loading()
                    } else {
                        self?.modelStatuses[model.id] = .downloading(progress: progress, bytesPerSecond: speed)
                    }
                }
            }
            modelStatuses[model.id] = .ready
            (engine as? WhisperEngine)?.onPhaseChange = nil
        } catch {
            (engine as? WhisperEngine)?.onPhaseChange = nil
            modelStatuses[model.id] = .error(error.localizedDescription)
            removeFromLoadedModels(model.id)
        }
    }

    func deleteModel(_ model: ModelInfo) {
        let engine = engine(for: model.engineType)
        engine.unloadModel()
        modelStatuses[model.id] = .notDownloaded
        removeFromLoadedModels(model.id)

        if selectedModelId == model.id {
            selectedModelId = nil
            UserDefaults.standard.removeObject(forKey: modelKey)
            activeEngine = nil
        }
    }

    private func addToLoadedModels(_ modelId: String) {
        var ids = UserDefaults.standard.stringArray(forKey: loadedModelsKey) ?? []
        let sameEngineIds = ModelInfo.allModels.map(\.id)
        ids.removeAll { sameEngineIds.contains($0) }
        ids.append(modelId)
        UserDefaults.standard.set(ids, forKey: loadedModelsKey)
    }

    private func removeFromLoadedModels(_ modelId: String) {
        var ids = UserDefaults.standard.stringArray(forKey: loadedModelsKey) ?? []
        ids.removeAll { $0 == modelId }
        UserDefaults.standard.set(ids, forKey: loadedModelsKey)
    }

    func status(for model: ModelInfo) -> ModelStatus {
        modelStatuses[model.id] ?? .notDownloaded
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask
    ) async throws -> TranscriptionResult {
        guard let engine = activeEngine else {
            throw TranscriptionEngineError.modelNotLoaded
        }
        return try await engine.transcribe(
            audioSamples: audioSamples,
            language: language,
            task: task
        )
    }

    func transcribe(
        audioSamples: [Float],
        language: String?,
        task: TranscriptionTask,
        onProgress: @Sendable @escaping (String) -> Bool
    ) async throws -> TranscriptionResult {
        guard let engine = activeEngine else {
            throw TranscriptionEngineError.modelNotLoaded
        }
        return try await engine.transcribe(
            audioSamples: audioSamples,
            language: language,
            task: task,
            onProgress: onProgress
        )
    }
}
