import Foundation
import GRDB

struct DocumentChunk: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: String
    var documentId: String
    var chunkText: String
    var chunkIndex: Int

    static let databaseTableName = "document_chunks"

    init(id: String = UUID().uuidString, documentId: String, chunkText: String, chunkIndex: Int) {
        self.id = id
        self.documentId = documentId
        self.chunkText = chunkText
        self.chunkIndex = chunkIndex
    }
}
