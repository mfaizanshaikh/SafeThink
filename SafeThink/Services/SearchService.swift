import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let snippet: String
    let url: String
}

@MainActor
final class SearchService: ObservableObject {
    static let shared = SearchService()

    @Published var isSearching = false
    @Published var results: [SearchResult] = []

    private let networkLogService = NetworkLogService.shared

    private init() {}

    func search(query: String) async throws -> [SearchResult] {
        isSearching = true
        defer { isSearching = false }

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = try Self.makeSearchURL(query: normalizedQuery)

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw SearchError.networkError
            }

            networkLogService.log(
                destination: "api.duckduckgo.com",
                purpose: "Web search: \(normalizedQuery)",
                dataSize: Int64(data.count)
            )

            let searchResults = try Self.parseResults(from: data)
            results = searchResults
            return searchResults
        } catch let error as SearchError {
            results = []
            throw error
        } catch {
            results = []
            throw SearchError.networkError
        }
    }

    static func makeSearchURL(query: String) throws -> URL {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            throw SearchError.invalidQuery
        }

        let encoded = normalizedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalizedQuery
        guard let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1") else {
            throw SearchError.invalidQuery
        }

        return url
    }

    static func parseResults(from data: Data) throws -> [SearchResult] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var searchResults: [SearchResult] = []

        if let abstract = json["Abstract"] as? String, !abstract.isEmpty {
            searchResults.append(SearchResult(
                title: json["Heading"] as? String ?? "Result",
                snippet: abstract,
                url: json["AbstractURL"] as? String ?? ""
            ))
        }

        searchResults.append(contentsOf: flattenRelatedTopics(json["RelatedTopics"] as? [[String: Any]]).prefix(5))
        return searchResults
    }

    private static func flattenRelatedTopics(_ topics: [[String: Any]]?) -> [SearchResult] {
        guard let topics else { return [] }

        var flattened: [SearchResult] = []
        for topic in topics {
            if let nestedTopics = topic["Topics"] as? [[String: Any]] {
                flattened.append(contentsOf: flattenRelatedTopics(nestedTopics))
                continue
            }

            if let text = topic["Text"] as? String,
               let firstURL = topic["FirstURL"] as? String {
                flattened.append(SearchResult(
                    title: String(text.prefix(80)),
                    snippet: text,
                    url: firstURL
                ))
            }
        }
        return flattened
    }
}

enum SearchError: Error, LocalizedError, Equatable {
    case invalidQuery
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidQuery: return "Invalid search query"
        case .networkError: return "Network error during search"
        }
    }
}
