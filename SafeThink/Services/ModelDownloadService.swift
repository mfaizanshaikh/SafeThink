import Foundation
import MLXLLM
import MLXLMCommon
import CommonCrypto

@MainActor
final class ModelDownloadService: ObservableObject {
    static let shared = ModelDownloadService()

    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadStatus: [String: ModelDownloadStatus] = [:]

    private var downloadTasks: [String: Task<Void, Error>] = [:]
    private let networkLogService = NetworkLogService.shared

    private var modelsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("models", isDirectory: true)
    }

    private init() {
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        refreshModelStatuses()
    }

    // MARK: - Status Management

    func refreshModelStatuses() {
        for model in ModelInfo.registry {
            let modelDir = modelsDirectory.appendingPathComponent(model.id)
            let markerFile = modelDir.appendingPathComponent(".download_complete")
            if FileManager.default.fileExists(atPath: markerFile.path) {
                downloadStatus[model.id] = .ready
            } else if downloadTasks[model.id] != nil {
                // Download in progress, keep current status
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

    // MARK: - Download via MLX Hub

    func downloadModel(_ model: ModelInfo) async throws {
        guard downloadTasks[model.id] == nil else { return }

        downloadStatus[model.id] = .downloading(progress: 0)
        downloadProgress[model.id] = 0

        // Log network request
        networkLogService.log(
            destination: "huggingface.co",
            purpose: "Model download: \(model.name)",
            dataSize: model.sizeBytes
        )

        do {
            // Use MLX's LLMModelFactory to download the model from HuggingFace.
            // ModelConfiguration.id() triggers Hub download + caching.
            // The model files are stored in MLX's Hub cache directory.
            let huggingFaceId = model.downloadURL
                .replacingOccurrences(of: "https://huggingface.co/", with: "")

            let configuration = ModelConfiguration(id: huggingFaceId)

            // loadContainer downloads (if not cached) and loads the model.
            // We track progress via the callback, then release the container.
            let _ = try await LLMModelFactory.shared.loadContainer(
                configuration: configuration
            ) { progress in
                Task { @MainActor in
                    let fraction = progress.fractionCompleted
                    self.downloadProgress[model.id] = fraction
                    self.downloadStatus[model.id] = .downloading(progress: fraction)
                }
            }

            // Mark download complete
            let destDir = modelsDirectory.appendingPathComponent(model.id)
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

            // Write a marker file indicating successful download
            let markerFile = destDir.appendingPathComponent(".download_complete")
            let metadata: [String: Any] = [
                "huggingFaceId": huggingFaceId,
                "downloadDate": ISO8601DateFormatter().string(from: Date()),
                "version": model.version,
                "sizeBytes": model.sizeBytes
            ]
            let metadataData = try JSONSerialization.data(withJSONObject: metadata)
            try metadataData.write(to: markerFile)

            // Exclude model files from iCloud backup
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableDestDir = destDir
            try mutableDestDir.setResourceValues(resourceValues)

            downloadStatus[model.id] = .ready
            downloadProgress[model.id] = 1.0

        } catch {
            downloadStatus[model.id] = .error(error.localizedDescription)
            downloadProgress[model.id] = 0
            throw error
        }

        downloadTasks.removeValue(forKey: model.id)
    }

    func cancelDownload(_ modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        downloadStatus[modelId] = .notDownloaded
        downloadProgress.removeValue(forKey: modelId)
    }

    func deleteModel(_ modelId: String) throws {
        // Cancel any in-progress download
        cancelDownload(modelId)

        // Remove our marker directory
        let modelDir = modelsDirectory.appendingPathComponent(modelId)
        if FileManager.default.fileExists(atPath: modelDir.path) {
            try FileManager.default.removeItem(at: modelDir)
        }

        // Also try to find and remove from MLX Hub cache
        let model = ModelInfo.registry.first { $0.id == modelId }
        if let model {
            let huggingFaceId = model.downloadURL
                .replacingOccurrences(of: "https://huggingface.co/", with: "")
            removeHubCache(for: huggingFaceId)
        }

        downloadStatus[modelId] = .notDownloaded
        downloadProgress.removeValue(forKey: modelId)
    }

    // MARK: - Storage Info

    func totalModelsSize() -> Int64 {
        var total: Int64 = 0

        // Check our models directory
        if let enumerator = FileManager.default.enumerator(
            at: modelsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }

        // Also check MLX Hub cache
        if let hubCacheDir = hubCacheDirectory() {
            if let enumerator = FileManager.default.enumerator(
                at: hubCacheDir,
                includingPropertiesForKeys: [.fileSizeKey]
            ) {
                for case let fileURL as URL in enumerator {
                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        total += Int64(size)
                    }
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

    // MARK: - Update Checking

    func checkForUpdates() async {
        // Check last update time (max once per day)
        let lastCheckKey = "lastModelUpdateCheck"
        if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(lastCheck) < 86400 {
            return
        }

        networkLogService.log(
            destination: "huggingface.co",
            purpose: "Check for model updates",
            dataSize: 1024
        )

        // For each downloaded model, check if HuggingFace has a newer version
        for model in ModelInfo.registry {
            guard downloadStatus[model.id] == .ready else { continue }

            let markerFile = modelsDirectory
                .appendingPathComponent(model.id)
                .appendingPathComponent(".download_complete")

            if let data = try? Data(contentsOf: markerFile),
               let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let savedVersion = metadata["version"] as? String,
               savedVersion != model.version {
                downloadStatus[model.id] = .updateAvailable
            }
        }

        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
    }

    // MARK: - Hub Cache Management

    private func hubCacheDirectory() -> URL? {
        // MLX Hub typically caches in the app's Caches directory
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
        return cacheDir
    }

    private func removeHubCache(for repoId: String) {
        guard let hubCache = hubCacheDirectory() else { return }
        let sanitizedId = repoId.replacingOccurrences(of: "/", with: "--")
        let modelCacheDir = hubCache.appendingPathComponent("models--\(sanitizedId)")
        try? FileManager.default.removeItem(at: modelCacheDir)
    }
}
