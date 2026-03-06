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

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1&skip_disambig=1") else {
            throw SearchError.invalidQuery
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        networkLogService.log(
            destination: "api.duckduckgo.com",
            purpose: "Web search: \(query)",
            dataSize: Int64(data.count)
        )

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var searchResults: [SearchResult] = []

        if let abstract = json["Abstract"] as? String, !abstract.isEmpty {
            searchResults.append(SearchResult(
                title: json["Heading"] as? String ?? "Result",
                snippet: abstract,
                url: json["AbstractURL"] as? String ?? ""
            ))
        }

        if let topics = json["RelatedTopics"] as? [[String: Any]] {
            for topic in topics.prefix(5) {
                if let text = topic["Text"] as? String,
                   let firstURL = topic["FirstURL"] as? String {
                    searchResults.append(SearchResult(
                        title: String(text.prefix(80)),
                        snippet: text,
                        url: firstURL
                    ))
                }
            }
        }

        results = searchResults
        return searchResults
    }
}

enum SearchError: Error, LocalizedError {
    case invalidQuery
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidQuery: return "Invalid search query"
        case .networkError: return "Network error during search"
        }
    }
}
