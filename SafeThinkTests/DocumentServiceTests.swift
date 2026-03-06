import XCTest
@testable import SafeThink

@MainActor
final class DocumentServiceTests: XCTestCase {
    func testChunkText() {
        let sut = DocumentService.shared
        let longText = String(repeating: "a", count: 5000)

        let chunks = sut.chunkText(longText)

        XCTAssertGreaterThan(chunks.count, 1)
        // First chunk should be chunkSize characters
        XCTAssertEqual(chunks[0].count, 2000)
    }

    func testChunkTextShort() {
        let sut = DocumentService.shared
        let shortText = "Hello world"

        let chunks = sut.chunkText(shortText)

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], "Hello world")
    }

    func testSuggestedActions() {
        let sut = DocumentService.shared

        let shortActions = sut.suggestedActions(for: "Short text")
        XCTAssertEqual(shortActions.count, 3)

        let longText = String(repeating: "a", count: 15000)
        let longActions = sut.suggestedActions(for: longText)
        XCTAssertEqual(longActions.count, 4)
        XCTAssertTrue(longActions.contains("Map-Reduce Summary"))
    }
}
