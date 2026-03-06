import Foundation
import MLX
import MLXLLM
import MLXLMCommon

enum InferenceError: Error, LocalizedError {
    case modelNotLoaded
    case generationFailed(String)
    case outOfMemory
    case cancelled

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "No model is currently loaded"
        case .generationFailed(let msg): return "Generation failed: \(msg)"
        case .outOfMemory: return "Insufficient memory for this operation"
        case .cancelled: return "Generation was cancelled"
        }
    }
}

@MainActor
final class InferenceService: ObservableObject {
    static let shared = InferenceService()

    @Published private(set) var isModelLoaded = false
    @Published private(set) var isGenerating = false
    @Published private(set) var loadedModelId: String?
    @Published private(set) var tokensPerSecond: Double = 0
    @Published private(set) var modelLoadProgress: Double = 0

    private var modelContainer: ModelContainer?
    private var generationTask: Task<Void, Never>?
    private var backgroundUnloadTask: Task<Void, Never>?
    private let backgroundUnloadDelay: TimeInterval = 30

    private init() {
        setupThermalMonitoring()
    }

    // MARK: - Model Loading

    /// Load model from a local directory containing MLX model files
    func loadModel(from directory: URL) async throws {
        unloadModel()
        modelLoadProgress = 0

        let configuration = ModelConfiguration(directory: directory)
        let container = try await LLMModelFactory.shared.loadContainer(
            configuration: configuration
        ) { progress in
            Task { @MainActor in
                self.modelLoadProgress = progress.fractionCompleted
            }
        }

        self.modelContainer = container
        self.isModelLoaded = true
        self.loadedModelId = directory.lastPathComponent
        self.modelLoadProgress = 1.0
    }

    /// Load model from a HuggingFace repository ID (downloads if needed)
    func loadModel(huggingFaceId: String) async throws {
        unloadModel()
        modelLoadProgress = 0

        let configuration = ModelConfiguration(id: huggingFaceId)
        let container = try await LLMModelFactory.shared.loadContainer(
            configuration: configuration
        ) { progress in
            Task { @MainActor in
                self.modelLoadProgress = progress.fractionCompleted
            }
        }

        self.modelContainer = container
        self.isModelLoaded = true
        self.loadedModelId = huggingFaceId
        self.modelLoadProgress = 1.0
    }

    func unloadModel() {
        cancelGeneration()
        backgroundUnloadTask?.cancel()
        backgroundUnloadTask = nil
        modelContainer = nil
        isModelLoaded = false
        loadedModelId = nil
        tokensPerSecond = 0
        modelLoadProgress = 0
    }

    // MARK: - Background Model Management

    /// Schedule model unload after delay (called when app enters background)
    func scheduleBackgroundUnload() {
        backgroundUnloadTask?.cancel()
        backgroundUnloadTask = Task {
            try? await Task.sleep(for: .seconds(backgroundUnloadDelay))
            if !Task.isCancelled {
                unloadModel()
            }
        }
    }

    /// Cancel any pending background unload (called when app returns to foreground)
    func cancelBackgroundUnload() {
        backgroundUnloadTask?.cancel()
        backgroundUnloadTask = nil
    }

    // MARK: - Thermal Monitoring

    private func setupThermalMonitoring() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleThermalChange()
        }
    }

    private func handleThermalChange() {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .serious, .critical:
            // Cancel ongoing generation to reduce thermal load
            if isGenerating {
                cancelGeneration()
            }
        default:
            break
        }
    }

    var thermalWarning: String? {
        switch ProcessInfo.processInfo.thermalState {
        case .serious: return "Device is warm. Performance may be reduced."
        case .critical: return "Device is overheating. Generation paused."
        default: return nil
        }
    }

    // MARK: - Text Generation

    func generate(
        messages: [[String: String]],
        maxTokens: Int = 2048,
        temperature: Float = 0.7,
        topP: Float = 0.9
    ) -> AsyncStream<String> {
        AsyncStream { continuation in
            generationTask = Task {
                guard let container = modelContainer else {
                    continuation.finish()
                    return
                }

                self.isGenerating = true
                let startTime = Date()
                var totalTokens = 0

                do {
                    let input = try await container.perform { context in
                        try await context.processor.prepare(input: .init(messages: messages))
                    }

                    let generateParameters = GenerateParameters(
                        temperature: temperature,
                        topP: topP
                    )

                    let result = try await container.perform { context in
                        try MLXLMCommon.generate(
                            input: input,
                            parameters: generateParameters,
                            context: context
                        ) { tokens in
                            if Task.isCancelled {
                                return .stop
                            }

                            // Check thermal state
                            if ProcessInfo.processInfo.thermalState == .critical {
                                return .stop
                            }

                            let text = context.tokenizer.decode(tokens: [tokens.last!])
                            totalTokens += 1

                            let elapsed = Date().timeIntervalSince(startTime)
                            if elapsed > 0 {
                                Task { @MainActor in
                                    self.tokensPerSecond = Double(totalTokens) / elapsed
                                }
                            }

                            continuation.yield(text)

                            if totalTokens >= maxTokens {
                                return .stop
                            }
                            return .more
                        }
                    }

                    _ = result

                } catch {
                    if !Task.isCancelled {
                        continuation.yield("\n[Error: \(error.localizedDescription)]")
                    }
                }

                self.isGenerating = false
                continuation.finish()
            }
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }
}
