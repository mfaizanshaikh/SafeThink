import Foundation
import MLXLLM
import MLXLMCommon
import CommonCrypto

@MainActor
final class ModelDownloadService: ObservableObject {
    static let shared = ModelDownloadService()

    typealias DownloadExecutor = @Sendable (
        ModelConfiguration,
        @Sendable @escaping (Progress) -> Void
    ) async throws -> URL

    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadStatus: [String: ModelDownloadStatus] = [:]

    private var downloadTasks: [String: Task<Void, Error>] = [:]
    private let networkLogService = NetworkLogService.shared
    private var downloadExecutor: DownloadExecutor = { configuration, progressHandler in
        try await MLXLMCommon.downloadModel(
            hub: defaultHubApi,
            configuration: configuration,
            progressHandler: progressHandler
        )
    }

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
            if hasCompletedDownload(for: model) {
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

        let task = Task<Void, Error> {
            let huggingFaceId = self.huggingFaceRepositoryID(for: model)
            let configuration = ModelConfiguration(id: huggingFaceId)

            let downloadedDirectory = try await self.downloadExecutor(configuration) { progress in
                Task { @MainActor in
                    let fraction = progress.fractionCompleted
                    self.downloadProgress[model.id] = fraction
                    self.downloadStatus[model.id] = .downloading(progress: fraction)
                }
            }

            try Task.checkCancellation()
            try self.validateDownloadedModelArtifacts(in: downloadedDirectory)
            await MainActor.run {
                self.downloadStatus[model.id] = .verifying
            }
            try self.writeDownloadMarker(for: model, huggingFaceId: huggingFaceId)
        }

        downloadTasks[model.id] = task
        defer { downloadTasks.removeValue(forKey: model.id) }

        do {
            try await task.value
            downloadStatus[model.id] = .ready
            downloadProgress[model.id] = 1.0
        } catch is CancellationError {
            resetDownloadState(for: model.id)
        } catch {
            downloadStatus[model.id] = .error(error.localizedDescription)
            downloadProgress[model.id] = 0
            throw error
        }
    }

    func cancelDownload(_ modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        resetDownloadState(for: modelId)
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
            removeCachedModelArtifacts(for: model)
        }

        resetDownloadState(for: modelId)
    }

    // MARK: - Storage Info

    func totalModelsSize() -> Int64 {
        var total: Int64 = 0

        for model in ModelInfo.registry {
            total += directorySize(at: modelDirectory(for: model.id))
            total += directorySize(at: cachedModelDirectory(for: model))
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

    func huggingFaceRepositoryID(for model: ModelInfo) -> String {
        model.downloadURL.replacingOccurrences(of: "https://huggingface.co/", with: "")
    }

    #if DEBUG
    func setDownloadTaskForTesting(_ task: Task<Void, Error>?, modelId: String) {
        downloadTasks[modelId] = task
    }

    func setDownloadExecutorForTesting(_ downloadExecutor: @escaping DownloadExecutor) {
        self.downloadExecutor = downloadExecutor
    }

    func resetDownloadExecutorForTesting() {
        downloadExecutor = { configuration, progressHandler in
            try await MLXLMCommon.downloadModel(
                hub: defaultHubApi,
                configuration: configuration,
                progressHandler: progressHandler
            )
        }
    }

    func cachedModelDirectoryForTesting(_ model: ModelInfo) -> URL {
        cachedModelDirectory(for: model)
    }
    #endif

    private func writeDownloadMarker(for model: ModelInfo, huggingFaceId: String) throws {
        let destDir = modelsDirectory.appendingPathComponent(model.id)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let markerFile = destDir.appendingPathComponent(".download_complete")
        let metadata: [String: Any] = [
            "huggingFaceId": huggingFaceId,
            "downloadDate": ISO8601DateFormatter().string(from: Date()),
            "version": model.version,
            "sizeBytes": model.sizeBytes
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        try metadataData.write(to: markerFile)

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDestDir = destDir
        try mutableDestDir.setResourceValues(resourceValues)
    }

    private func resetDownloadState(for modelId: String) {
        downloadStatus[modelId] = .notDownloaded
        downloadProgress.removeValue(forKey: modelId)
    }

    private func hasCompletedDownload(for model: ModelInfo) -> Bool {
        let markerFile = modelDirectory(for: model.id).appendingPathComponent(".download_complete")
        guard FileManager.default.fileExists(atPath: markerFile.path) else {
            return false
        }

        return hasValidModelArtifacts(in: cachedModelDirectory(for: model))
    }

    private func cachedModelDirectory(for model: ModelInfo) -> URL {
        ModelConfiguration(id: huggingFaceRepositoryID(for: model)).modelDirectory(hub: defaultHubApi)
    }

    private func removeCachedModelArtifacts(for model: ModelInfo) {
        let cachedDirectory = cachedModelDirectory(for: model)
        try? FileManager.default.removeItem(at: cachedDirectory)
    }

    private func validateDownloadedModelArtifacts(in directory: URL) throws {
        guard hasValidModelArtifacts(in: directory) else {
            throw NSError(
                domain: "ModelDownloadService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Downloaded model is missing required MLX artifacts."]
            )
        }
    }

    private func hasValidModelArtifacts(in directory: URL) -> Bool {
        var hasConfig = false
        var hasWeights = false

        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return false
        }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "config.json" {
                hasConfig = true
            } else if fileURL.pathExtension == "safetensors" {
                hasWeights = true
            }

            if hasConfig && hasWeights {
                return true
            }
        }

        return false
    }

    private func directorySize(at directory: URL) -> Int64 {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return 0
        }

        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }
}
