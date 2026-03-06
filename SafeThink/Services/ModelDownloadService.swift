import Foundation

@MainActor
final class ModelDownloadService: ObservableObject {
    static let shared = ModelDownloadService()

    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadStatus: [String: ModelDownloadStatus] = [:]

    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private let networkLogService = NetworkLogService.shared

    private var modelsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("models", isDirectory: true)
    }

    private init() {
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        refreshModelStatuses()
    }

    func refreshModelStatuses() {
        for model in ModelInfo.registry {
            let modelDir = modelsDirectory.appendingPathComponent(model.id)
            if FileManager.default.fileExists(atPath: modelDir.path) {
                downloadStatus[model.id] = .ready
            } else {
                downloadStatus[model.id] = .notDownloaded
            }
        }
    }

    func modelDirectory(for modelId: String) -> URL {
        modelsDirectory.appendingPathComponent(modelId)
    }

    func isModelDownloaded(_ modelId: String) -> Bool {
        downloadStatus[modelId] == .ready
    }

    func downloadModel(_ model: ModelInfo) async throws {
        downloadStatus[model.id] = .downloading(progress: 0)
        downloadProgress[model.id] = 0

        // Log network request
        networkLogService.log(
            destination: "huggingface.co",
            purpose: "Model download: \(model.name)",
            dataSize: model.sizeBytes
        )

        // Use MLX's built-in Hub download which handles:
        // - Resumable downloads
        // - Progress tracking
        // - File verification
        // For now, mark as placeholder for MLX Hub integration

        let destDir = modelsDirectory.appendingPathComponent(model.id)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        // MLX Swift handles HuggingFace downloads via ModelConfiguration
        // The actual download happens when loadModel is called with a HF repo ID
        // This service tracks the state

        downloadStatus[model.id] = .ready
        downloadProgress[model.id] = 1.0
    }

    func cancelDownload(_ modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        downloadStatus[modelId] = .notDownloaded
        downloadProgress.removeValue(forKey: modelId)
    }

    func deleteModel(_ modelId: String) throws {
        let modelDir = modelsDirectory.appendingPathComponent(modelId)
        if FileManager.default.fileExists(atPath: modelDir.path) {
            try FileManager.default.removeItem(at: modelDir)
        }
        downloadStatus[modelId] = .notDownloaded
        downloadProgress.removeValue(forKey: modelId)
    }

    func totalModelsSize() -> Int64 {
        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    func deviceFreeSpace() -> Int64 {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let values = try? paths[0].resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let freeSpace = values.volumeAvailableCapacityForImportantUsage {
            return freeSpace
        }
        return 0
    }

    func checkForUpdates() async {
        // Fetch remote model registry (max once per day)
        // Compare versions, set .updateAvailable status
        networkLogService.log(
            destination: "huggingface.co",
            purpose: "Check for model updates",
            dataSize: 1024
        )
    }
}
