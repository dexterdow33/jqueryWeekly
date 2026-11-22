import Foundation
import Observation

/// The site's category tree. Loaded once, cached, refreshed quietly.
@MainActor
@Observable
final class SectionStore {
    private(set) var categories: [NewsCategory] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var byID: [Int: NewsCategory] = [:]
    private let api = WordPressAPI.shared
    private let fileName = "categories"

    init() {
        if let cached = DiskStore.caches.load([NewsCategory].self, named: fileName) {
            apply(cached)
        }
    }

    var topLevel: [NewsCategory] {
        categories
            .filter { $0.parent == 0 }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func children(of category: NewsCategory) -> [NewsCategory] {
        categories
            .filter { $0.parent == category.id }
            .sorted { $0.count > $1.count }
    }

    func category(id: Int) -> NewsCategory? {
        byID[id]
    }

    /// The label shown above a headline: the most specific section the story is filed under.
    func kicker(for article: Article) -> String? {
        let known = article.categoryIDs.compactMap { byID[$0] }
        return (known.first { $0.parent != 0 } ?? known.first)?.name
    }

    func load(force: Bool = false) async {
        guard !isLoading, force || categories.isEmpty || errorMessage != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await api.categories()
            apply(fresh)
            errorMessage = nil
            DiskStore.caches.save(fresh, named: fileName)
        } catch is CancellationError {
            return
        } catch {
            if categories.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func apply(_ list: [NewsCategory]) {
        categories = list.filter { $0.count > 0 }
        byID = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
