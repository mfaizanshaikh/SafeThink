import XCTest
@testable import SafeThink

@MainActor
final class ModelDownloadServiceIntegrationTests: XCTestCase {
    private let sut = ModelDownloadService.shared
    #if RUN_MLX_HF_INTEGRATION_TESTS
    private let compileTimeIntegrationTestsEnabled = true
    #else
    private let compileTimeIntegrationTestsEnabled = false
    #endif

    override func tearDown() {
        cleanupArtifacts(for: integrationModel)
        super.tearDown()
    }

    func testRealHuggingFaceMLXDownloadPath() async throws {
        guard compileTimeIntegrationTestsEnabled
            || ProcessInfo.processInfo.environment["RUN_MLX_HF_INTEGRATION_TESTS"] == "1"
        else {
            throw XCTSkip("Set RUN_MLX_HF_INTEGRATION_TESTS=1 to run networked MLX download tests.")
        }

        cleanupArtifacts(for: integrationModel)
        sut.downloadStatus[integrationModel.id] = nil
        sut.downloadProgress[integrationModel.id] = nil

        try await sut.downloadModel(integrationModel)

        XCTAssertEqual(sut.downloadStatus[integrationModel.id], .ready)
        XCTAssertEqual(sut.downloadProgress[integrationModel.id], 1.0)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: sut.modelDirectory(for: integrationModel.id)
                    .appendingPathComponent(".download_complete")
                    .path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: sut.cachedModelDirectoryForTesting(integrationModel)
                    .appendingPathComponent("config.json")
                    .path
            )
        )
        XCTAssertTrue(hasSafetensors(in: sut.cachedModelDirectoryForTesting(integrationModel)))
    }

    private var integrationModel: ModelInfo {
        let repositoryId = ProcessInfo.processInfo.environment["HF_MLX_TEST_REPO"]
            ?? "mlx-community/SmolLM-135M-Instruct-4bit"

        return ModelInfo(
            id: "integration-\(repositoryId.replacingOccurrences(of: "/", with: "-"))",
            name: "Integration Download",
            displayName: "Integration Download",
            parameterCount: "0.1B",
            quantization: "4-bit",
            sizeBytes: 100_000_000,
            downloadURL: "https://huggingface.co/\(repositoryId)",
            sha256Checksum: "",
            minRAMGB: 4,
            contextLength: 2048,
            isMultimodal: false,
            version: "integration"
        )
    }

    private func cleanupArtifacts(for model: ModelInfo) {
        try? FileManager.default.removeItem(at: sut.modelDirectory(for: model.id))
        try? FileManager.default.removeItem(at: sut.cachedModelDirectoryForTesting(model))
    }

    private func hasSafetensors(in directory: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return false
        }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "safetensors" {
            return true
        }
        return false
    }
}
