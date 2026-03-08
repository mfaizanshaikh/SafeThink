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
            id: "qwen3-0.6b",
            name: "Qwen3-0.6B",
            displayName: "Qwen 3 Tiny",
            parameterCount: "0.6B",
            quantization: "4-bit",
            sizeBytes: 500_000_000,
            downloadURL: "https://huggingface.co/mlx-community/Qwen3-0.6B-4bit",
            sha256Checksum: "",
            minRAMGB: 4,
            contextLength: 32768,
            isMultimodal: false,
            version: "1.0"
        ),
        ModelInfo(
            id: "qwen3-4b",
            name: "Qwen3-4B",
            displayName: "Qwen 3 Medium",
            parameterCount: "4B",
            quantization: "4-bit",
            sizeBytes: 2_500_000_000,
            downloadURL: "https://huggingface.co/mlx-community/Qwen3-4B-4bit",
            sha256Checksum: "",
            minRAMGB: 8,
            contextLength: 32768,
            isMultimodal: false,
            version: "1.0"
        ),
        ModelInfo(
            id: "qwen3-1.7b",
            name: "Qwen3-1.7B",
            displayName: "Qwen 3 1.7B",
            parameterCount: "1.7B",
            quantization: "4-bit",
            sizeBytes: 1_100_000_000,
            downloadURL: "https://huggingface.co/mlx-community/Qwen3-1.7B-4bit",
            sha256Checksum: "",
            minRAMGB: 4,
            contextLength: 32768,
            isMultimodal: false,
            version: "1.0"
        ),
        ModelInfo(
            id: "phi-3.5-mini",
            name: "Phi-3.5-Mini",
            displayName: "Phi 3.5 Mini",
            parameterCount: "3.8B",
            quantization: "4-bit",
            sizeBytes: 2_200_000_000,
            downloadURL: "https://huggingface.co/mlx-community/Phi-3.5-mini-instruct-4bit",
            sha256Checksum: "",
            minRAMGB: 6,
            contextLength: 131072,
            isMultimodal: false,
            version: "1.0"
        ),
        ModelInfo(
            id: "llama-3.2-3b",
            name: "Llama-3.2-3B",
            displayName: "Llama 3.2 3B",
            parameterCount: "3B",
            quantization: "4-bit",
            sizeBytes: 1_800_000_000,
            downloadURL: "https://huggingface.co/mlx-community/Llama-3.2-3B-Instruct-4bit",
            sha256Checksum: "",
            minRAMGB: 6,
            contextLength: 131072,
            isMultimodal: false,
            version: "1.0"
        ),
        ModelInfo(
            id: "gemma-3-1b",
            name: "Gemma-3-1B",
            displayName: "Gemma 3 1B",
            parameterCount: "1B",
            quantization: "4-bit",
            sizeBytes: 700_000_000,
            downloadURL: "https://huggingface.co/mlx-community/gemma-3-1b-it-qat-4bit",
            sha256Checksum: "",
            minRAMGB: 4,
            contextLength: 32768,
            isMultimodal: false,
            version: "1.0"
        )
    ]
}
