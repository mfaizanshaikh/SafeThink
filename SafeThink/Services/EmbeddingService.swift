import Foundation

@MainActor
final class EmbeddingService: ObservableObject {
    static let shared = EmbeddingService()

    @Published private(set) var isModelLoaded = false

    private let embeddingDimension = 384

    private init() {}

    func loadModel() async throws {
        // Load all-MiniLM-L6-v2 for text embeddings
        // Model path: <app>/embeddings/all-MiniLM-L6-v2/
        let embeddingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("embeddings")

        if FileManager.default.fileExists(atPath: embeddingsDir.appendingPathComponent("all-MiniLM-L6-v2").path) {
            isModelLoaded = true
        }
    }

    func embed(text: String) async throws -> [Float] {
        guard isModelLoaded else {
            throw EmbeddingError.modelNotLoaded
        }

        // Tokenize and encode text through all-MiniLM-L6-v2
        // Returns 384-dimensional normalized vector
        // Placeholder: actual implementation uses swift-embeddings or MLX
        return [Float](repeating: 0.0, count: embeddingDimension)
    }

    func embedBatch(texts: [String]) async throws -> [[Float]] {
        var results: [[Float]] = []
        for text in texts {
            let embedding = try await embed(text: text)
            results.append(embedding)
        }
        return results
    }

    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }
}

enum EmbeddingError: Error, LocalizedError {
    case modelNotLoaded
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Embedding model not loaded"
        case .encodingFailed: return "Failed to encode text"
        }
    }
}
