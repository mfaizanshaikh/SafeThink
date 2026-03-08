import XCTest
@testable import SafeThink

@MainActor
final class ModelDownloadServiceTests: XCTestCase {
    private let sut = ModelDownloadService.shared
    private let model = ModelInfo.registry[0]

    override func setUp() {
        super.setUp()
        cleanupModelArtifacts()
        sut.resetDownloadExecutorForTesting()
        sut.downloadStatus[model.id] = nil
        sut.downloadProgress[model.id] = nil
    }

    override func tearDown() {
        sut.cancelDownload(model.id)
        cleanupModelArtifacts()
        sut.resetDownloadExecutorForTesting()
        super.tearDown()
    }

    func testRefreshModelStatusesMarksDownloadedModelReady() throws {
        let modelDir = sut.modelDirectory(for: model.id)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        let marker = modelDir.appendingPathComponent(".download_complete")
        try Data("{}".utf8).write(to: marker)
        try createCachedModelArtifacts()

        sut.refreshModelStatuses()

        XCTAssertEqual(sut.downloadStatus[model.id], .ready)
    }

    func testRefreshModelStatusesTreatsMarkerWithoutCacheAsNotDownloaded() throws {
        let modelDir = sut.modelDirectory(for: model.id)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        let marker = modelDir.appendingPathComponent(".download_complete")
        try Data("{}".utf8).write(to: marker)

        sut.refreshModelStatuses()

        XCTAssertEqual(sut.downloadStatus[model.id], .notDownloaded)
    }

    func testCancelDownloadResetsVisibleState() {
        let task = Task<Void, Error> {
            try await Task.sleep(for: .seconds(60))
        }
        sut.downloadStatus[model.id] = .downloading(progress: 0.4)
        sut.downloadProgress[model.id] = 0.4
        sut.setDownloadTaskForTesting(task, modelId: model.id)

        sut.cancelDownload(model.id)

        XCTAssertEqual(sut.downloadStatus[model.id], .notDownloaded)
        XCTAssertNil(sut.downloadProgress[model.id])
    }

    func testHuggingFaceRepositoryIDStripsHostPrefix() {
        XCTAssertEqual(
            sut.huggingFaceRepositoryID(for: model),
            "mlx-community/Qwen3-0.6B-4bit"
        )
    }

    func testDownloadModelMarksReadyAfterPureDownloadCompletes() async throws {
        let cachedDirectory = sut.cachedModelDirectoryForTesting(model)
        sut.setDownloadExecutorForTesting { _, progressHandler in
            progressHandler(Progress(totalUnitCount: 100))
            try FileManager.default.createDirectory(at: cachedDirectory, withIntermediateDirectories: true)
            try Data("{}".utf8).write(to: cachedDirectory.appendingPathComponent("config.json"))
            try Data("weights".utf8).write(to: cachedDirectory.appendingPathComponent("model.safetensors"))

            let progress = Progress(totalUnitCount: 100)
            progress.completedUnitCount = 100
            progressHandler(progress)
            return cachedDirectory
        }

        try await sut.downloadModel(model)

        XCTAssertEqual(sut.downloadStatus[model.id], .ready)
        XCTAssertEqual(sut.downloadProgress[model.id], 1.0)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: sut.modelDirectory(for: model.id)
                    .appendingPathComponent(".download_complete")
                    .path
            )
        )
    }

    func testDeleteModelRemovesCachedArtifactsAtMLXHubLocation() throws {
        try createCachedModelArtifacts()
        let markerDirectory = sut.modelDirectory(for: model.id)
        try FileManager.default.createDirectory(at: markerDirectory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: markerDirectory.appendingPathComponent(".download_complete"))

        try sut.deleteModel(model.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sut.cachedModelDirectoryForTesting(model).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: markerDirectory.path))
    }

    private func cleanupModelArtifacts() {
        let modelDir = sut.modelDirectory(for: model.id)
        try? FileManager.default.removeItem(at: modelDir)
        try? FileManager.default.removeItem(at: sut.cachedModelDirectoryForTesting(model))
    }

    private func createCachedModelArtifacts() throws {
        let cachedDirectory = sut.cachedModelDirectoryForTesting(model)
        try FileManager.default.createDirectory(at: cachedDirectory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: cachedDirectory.appendingPathComponent("config.json"))
        try Data("weights".utf8).write(to: cachedDirectory.appendingPathComponent("model.safetensors"))
    }
}
