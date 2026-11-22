import Foundation
import Observation

/// A paged list of stories: the front page, one section, or a search.
@MainActor
@Observable
final class FeedModel {
    enum Query: Hashable {
        case latest
        case category(Int)
        case search(String)
    }

    private(set) var query: Query
    private(set) var articles: [Article] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    /// True when the list on screen came from the cache because the network failed.
    private(set) var isShowingCache = false

    @ObservationIgnored private var page = 0
    @ObservationIgnored private var totalPages = 1
    @ObservationIgnored private var generation = 0
    private let cacheName: String?
    private let api = WordPressAPI.shared

    init(query: Query, cacheName: String? = nil) {
        self.query = query
        self.cacheName = cacheName
    }

    var canLoadMore: Bool { hasLoaded && page < totalPages }

    func setQuery(_ newQuery: Query) {
        guard newQuery != query else { return }
        query = newQuery
        generation += 1
        articles = []
        hasLoaded = false
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
        page = 0
        totalPages = 1
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        await reload()
    }

    /// For pull-to-refresh. Runs detached from the gesture so a view update cannot cancel the request.
    func refresh() async {
        await Task { await self.reload() }.value
    }

    func reload() async {
        generation += 1
        let current = generation
        isLoading = true
        errorMessage = nil

        if articles.isEmpty, let cacheName,
           let cached = DiskStore.caches.load([Article].self, named: cacheName) {
            articles = cached
        }

        do {
            let result = try await fetch(page: 1)
            guard current == generation else { return }
            articles = result.articles
            page = 1
            totalPages = result.totalPages
            hasLoaded = true
            isShowingCache = false
            if let cacheName {
                DiskStore.caches.save(result.articles, named: cacheName)
            }
            if query == .latest {
                NewStoryMonitor.markSeen(result.articles)
            }
        } catch is CancellationError {
            if current == generation { isLoading = false }
            return
        } catch {
            guard current == generation else { return }
            if articles.isEmpty {
                errorMessage = error.localizedDescription
            } else {
                isShowingCache = true
            }
        }
        isLoading = false
    }

    func loadMoreIfNeeded(after article: Article) async {
        guard canLoadMore, !isLoading, !isLoadingMore,
              let index = articles.firstIndex(where: { $0.id == article.id }),
              index >= articles.count - 4
        else { return }

        let current = generation
        isLoadingMore = true
        defer { if current == generation { isLoadingMore = false } }

        do {
            let result = try await fetch(page: page + 1)
            guard current == generation else { return }
            let known = Set(articles.map(\.id))
            articles.append(contentsOf: result.articles.filter { !known.contains($0.id) })
            page += 1
            totalPages = result.totalPages
        } catch {
            // Leave the list as it is. Scrolling again retries.
        }
    }

    private func fetch(page: Int) async throws -> PostPage {
        switch query {
        case .latest:
            return try await api.posts(page: page)
        case .category(let id):
            return try await api.posts(page: page, category: id)
        case .search(let text):
            return try await api.posts(page: page, search: text)
        }
    }
}
