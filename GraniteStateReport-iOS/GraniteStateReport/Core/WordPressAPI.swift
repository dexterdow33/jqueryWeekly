import Foundation

enum APIError: LocalizedError {
    case offline
    case server(Int)
    case notFound
    case badResponse

    var errorDescription: String? {
        switch self {
        case .offline:
            return "No connection. Check your network and try again."
        case .server(let code):
            return "The site returned an error (\(code)). Try again in a moment."
        case .notFound:
            return "That story could not be found."
        case .badResponse:
            return "The site sent something the app could not read."
        }
    }
}

struct PostPage {
    let articles: [Article]
    let totalPages: Int
}

/// Read-only client for the site's public WordPress REST API. No keys, no login, no tracking.
final class WordPressAPI {
    static let shared = WordPressAPI()

    private let session: URLSession
    private let decoder = JSONDecoder()

    private static let listFields = "id,date_gmt,slug,link,title,excerpt,categories,jetpack_featured_media_url"
    private static let fullFields = listFields + ",content"

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 40
            configuration.httpAdditionalHeaders = ["Accept": "application/json"]
            self.session = URLSession(configuration: configuration)
        }
    }

    // MARK: Posts

    func posts(page: Int = 1,
               perPage: Int = 20,
               category: Int? = nil,
               search: String? = nil) async throws -> PostPage {
        var query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "_fields", value: WordPressAPI.listFields)
        ]
        if let category {
            query.append(URLQueryItem(name: "categories", value: String(category)))
        }
        if let search, !search.isEmpty {
            query.append(URLQueryItem(name: "search", value: search))
        }
        let (data, response) = try await data(path: "/wp/v2/posts", query: query)
        let dtos = try decode([PostDTO].self, from: data)
        let total = Int(response.value(forHTTPHeaderField: "X-WP-TotalPages") ?? "") ?? page
        return PostPage(articles: dtos.compactMap { $0.article() }, totalPages: max(total, 1))
    }

    func post(id: Int) async throws -> Article {
        let query = [URLQueryItem(name: "_fields", value: WordPressAPI.fullFields)]
        let (data, _) = try await data(path: "/wp/v2/posts/\(id)", query: query)
        guard let article = try decode(PostDTO.self, from: data).article() else {
            throw APIError.badResponse
        }
        return article
    }

    func post(slug: String) async throws -> Article {
        let query = [
            URLQueryItem(name: "slug", value: slug),
            URLQueryItem(name: "_fields", value: WordPressAPI.fullFields)
        ]
        let (data, _) = try await data(path: "/wp/v2/posts", query: query)
        guard let article = try decode([PostDTO].self, from: data).first?.article() else {
            throw APIError.notFound
        }
        return article
    }

    // MARK: Sections

    func categories() async throws -> [NewsCategory] {
        let query = [
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "hide_empty", value: "true"),
            URLQueryItem(name: "_fields", value: "id,name,slug,count,parent")
        ]
        let (data, _) = try await data(path: "/wp/v2/categories", query: query)
        return try decode([NewsCategory].self, from: data).map { category in
            var decoded = category
            decoded.name = HTMLText.decodeEntities(category.name)
            return decoded
        }
    }

    // MARK: Site features

    func liveStatus() async throws -> LiveStatus {
        let (data, _) = try await data(path: "/gsr-live/v1/status", query: [])
        return try decode(LiveStatus.self, from: data)
    }

    func mediaCatalog() async throws -> MediaCatalog {
        let (data, _) = try await data(path: "/gsr-radio/v1/stations", query: [])
        return try decode(MediaCatalog.self, from: data)
    }

    // MARK: Plumbing

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.badResponse
        }
    }

    private func data(path: String, query: [URLQueryItem]) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(string: GSR.apiBaseURL.absoluteString + path) else {
            throw APIError.badResponse
        }
        if !query.isEmpty {
            components.queryItems = query
            // URLComponents leaves "+" alone and WordPress reads it as a space.
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }
        guard let url = components.url else { throw APIError.badResponse }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
            switch http.statusCode {
            case 200..<300:
                return (data, http)
            case 404:
                throw APIError.notFound
            default:
                throw APIError.server(http.statusCode)
            }
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw APIError.offline
        }
    }
}
