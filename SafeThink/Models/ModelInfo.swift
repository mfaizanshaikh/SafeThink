import Foundation

enum ModelCompatibility: String, Codable {
    case compatible     // green
    case limited        // yellow - may be slow
    case incompatible   // red - insufficient RAM
}

enum ModelDownloadStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case verifying
    case ready
    case error(String)
    case updateAvailable
}

struct ModelInfo: Codable, Identifiable {
    let id: String
    let name: String
    let displayName: String
    let parameterCount: String // e.g. "0.8B", "2B"
    let quantization: String   // e.g. "4-bit"
    let sizeBytes: Int64
    let downloadURL: String
    let sha256Checksum: String
    let minRAMGB: Int
    let contextLength: Int
    let isMultimodal: Bool
    let version: String

    var sizeFormatted: String {
        let gb = Double(sizeBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }

    static let registry: [ModelInfo] = [
        ModelInfo(
            id: "qwen3.5-0.8b",
            name: "Qwen3.5-0.8B",
            displayName: "Qwen 3.5 Tiny",
            parameterCount: "0.8B",
            quantization: "4-bit",
            sizeBytes: 750_000_000,
            downloadURL: "https://huggingface.co/mlx-community/Qwen3.5-0.8B-4bit",
            sha256Checksum: "",
            minRAMGB: 4,
            contextLength: 8192,
            isMultimodal: true,
            version: "1.0"
        ),
        ModelInfo(
            id: "qwen3.5-2b",
            name: "Qwen3.5-2B",
            displayName: "Qwen 3.5 Small",
            parameterCount: "2B",
            quantization: "4-bit",
            sizeBytes: 1_500_000_000,
            downloadURL: "https://huggingface.co/mlx-community/Qwen3.5-2B-4bit",
            sha256Checksum: "",
            minRAMGB: 6,
            contextLength: 16384,
            isMultimodal: true,
            version: "1.0"
        ),
        ModelInfo(
            id: "qwen3.5-4b",
            name: "Qwen3.5-4B",
            displayName: "Qwen 3.5 Medium",
            parameterCount: "4B",
            quantization: "4-bit",
            sizeBytes: 2_800_000_000,
            downloadURL: "https://huggingface.co/mlx-community/Qwen3.5-4B-4bit",
            sha256Checksum: "",
            minRAMGB: 8,
            contextLength: 32768,
            isMultimodal: true,
            version: "1.0"
        ),
        ModelInfo(
            id: "qwen3.5-9b",
            name: "Qwen3.5-9B",
            displayName: "Qwen 3.5 Large",
            parameterCount: "9B",
            quantization: "4-bit",
            sizeBytes: 5_500_000_000,
            downloadURL: "https://huggingface.co/mlx-community/Qwen3.5-9B-4bit",
            sha256Checksum: "",
            minRAMGB: 12,
            contextLength: 32768,
            isMultimodal: true,
            version: "1.0"
        )
    ]
}
