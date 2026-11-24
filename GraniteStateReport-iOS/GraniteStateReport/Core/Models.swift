import Foundation

// MARK: - Article

/// One GSR story. This is the app's own model: it is what gets cached and saved.
struct Article: Identifiable, Hashable, Codable {
    let id: Int
    var date: Date
    var slug: String
    var link: URL
    var title: String
    var excerpt: String
    var imageURL: URL?
    var categoryIDs: [Int]
    /// The full article body. Lists leave this nil; it is fetched when the story is opened or saved.
    var contentHTML: String?

    /// Narration file for the article, when the body carries one.
    var audioURL: URL? {
        guard let contentHTML else { return nil }
        return HTMLText.firstAudioURL(in: contentHTML)
    }

    /// Featured image sized for the slot it will fill. Uses the site's image CDN when the URL allows it.
    func image(width: Int) -> URL? {
        guard let imageURL, let host = imageURL.host, host.hasSuffix(".wp.com"),
              var components = URLComponents(url: imageURL, resolvingAgainstBaseURL: false)
        else { return imageURL }
        components.queryItems = [
            URLQueryItem(name: "w", value: String(width)),
            URLQueryItem(name: "quality", value: "80"),
            URLQueryItem(name: "ssl", value: "1")
        ]
        return components.url ?? imageURL
    }
}

/// The WordPress REST shape of a post. Decoded, then mapped to `Article`.
struct PostDTO: Decodable {
    struct Rendered: Decodable {
        let rendered: String
    }

    let id: Int
    let dateGMT: String
    let slug: String
    let link: String
    let title: Rendered
    let excerpt: Rendered?
    let content: Rendered?
    let categories: [Int]?
    let featuredImage: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, link, title, excerpt, content, categories
        case dateGMT = "date_gmt"
        case featuredImage = "jetpack_featured_media_url"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    func article() -> Article? {
        guard let url = URL(string: link) else { return nil }
        let image = featuredImage.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        return Article(
            id: id,
            date: PostDTO.dateFormatter.date(from: dateGMT) ?? Date(),
            slug: slug,
            link: url,
            title: HTMLText.plain(title.rendered),
            excerpt: HTMLText.plain(excerpt?.rendered ?? ""),
            imageURL: image,
            categoryIDs: categories ?? [],
            contentHTML: content?.rendered
        )
    }
}

// MARK: - Sections

struct NewsCategory: Identifiable, Hashable, Codable {
    let id: Int
    var name: String
    var slug: String
    var count: Int
    var parent: Int
}

// MARK: - Live status

struct LiveStatus: Decodable, Equatable {
    let live: Bool
    let title: String?
    let url: String?
    let livePage: String?
    let label: String?

    enum CodingKeys: String, CodingKey {
        case live, title, url, label
        case livePage = "live_page"
    }

    var watchURL: URL? {
        if let url, let parsed = URL(string: url) { return parsed }
        if let livePage, let parsed = URL(string: livePage) { return parsed }
        return nil
    }
}

// MARK: - Media catalog (podcast, narrated articles, video)

struct MediaCatalog: Decodable {
    let tabs: [MediaTab]
}

struct MediaTab: Decodable, Identifiable, Hashable {
    let id: String
    let label: String?
    let note: String?
    let items: [MediaItem]

    var displayName: String {
        let trimmed = (label ?? "").trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? id.capitalized : HTMLText.decodeEntities(trimmed)
    }
}

struct MediaItem: Decodable, Hashable {
    let kind: String
    let id: String?
    let src: String?
    let title: String
    let link: String?
    let sub: String?
    let live: Bool?

    var isAudio: Bool { kind == "audio" && audioURL != nil }
    var isVideo: Bool { kind == "yt" || kind == "ytlist" }
    var isLive: Bool { live ?? false }

    var displayTitle: String { HTMLText.decodeEntities(title) }
    var audioURL: URL? { src.flatMap { URL(string: $0) } }
    var linkURL: URL? { link.flatMap { URL(string: $0) } }

    /// YouTube still for a single video. Playlists have none.
    var thumbnailURL: URL? {
        guard kind == "yt", let id, !id.isEmpty else { return nil }
        return URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg")
    }
}
