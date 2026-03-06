import Foundation

@MainActor
final class MemoryService: ObservableObject {
    static let shared = MemoryService()

    @Published var memories: [Memory] = []

    private let databaseService = DatabaseService.shared
    private let embeddingService = EmbeddingService.shared

    private init() {
        loadMemories()
    }

    func loadMemories() {
        memories = (try? databaseService.fetchAllMemories()) ?? []
    }

    func saveMemory(_ memory: Memory) throws {
        try databaseService.createMemory(memory)
        loadMemories()
    }

    func deleteMemory(id: String) throws {
        try databaseService.deleteMemory(id: id)
        loadMemories()
    }

    func extractMemoryCandidates(from conversation: [Message]) -> [String] {
        var candidates: [String] = []
        for message in conversation where message.role == .user {
            let text = message.content.lowercased()
            if text.contains("i prefer") || text.contains("i like") || text.contains("i always") ||
               text.contains("my name is") || text.contains("i work") || text.contains("i am a") ||
               text.contains("please remember") || text.contains("don't forget") {
                candidates.append(message.content)
            }
        }
        return candidates
    }

    func retrieveRelevantMemories(for query: String, topK: Int = 5) async throws -> [Memory] {
        guard embeddingService.isModelLoaded else { return [] }

        let queryEmbedding = try await embeddingService.embed(text: query)

        var scored: [(memory: Memory, score: Float)] = []
        for memory in memories {
            let memEmbedding = try await embeddingService.embed(text: memory.memoryText)
            let score = embeddingService.cosineSimilarity(queryEmbedding, memEmbedding)
            scored.append((memory, score))
        }

        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(topK).map(\.memory))
    }

    func buildMemoryContext(for query: String) async -> String {
        guard let relevant = try? await retrieveRelevantMemories(for: query, topK: 5),
              !relevant.isEmpty else {
            return ""
        }

        var context = "Relevant memories about the user:\n"
        for memory in relevant {
            context += "- [\(memory.memoryType.rawValue)] \(memory.memoryText)\n"
        }
        return context
    }

    func clearAllMemories() throws {
        try databaseService.deleteAllMemories()
        memories = []
    }
}
