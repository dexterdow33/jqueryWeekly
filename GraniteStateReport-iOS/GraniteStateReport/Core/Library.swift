import Foundation
import Observation

/// Saved stories. Each is stored with its full text so it reads without a connection.
@MainActor
@Observable
final class Library {
    private(set) var saved: [Article] = []

    private let fileName = "saved"
    private let api = WordPressAPI.shared

    init() {
        saved = DiskStore.documents.load([Article].self, named: fileName) ?? []
    }

    func isSaved(_ article: Article) -> Bool {
        saved.contains { $0.id == article.id }
    }

    func savedCopy(id: Int) -> Article? {
        saved.first { $0.id == id }
    }

    func savedCopy(slug: String) -> Article? {
        saved.first { $0.slug == slug }
    }

    func toggle(_ article: Article) {
        if isSaved(article) {
            remove(article)
        } else {
            save(article)
        }
    }

    func save(_ article: Article) {
        guard !isSaved(article) else { return }
        saved.insert(article, at: 0)
        persist()
        if article.contentHTML == nil {
            Task { await fetchBody(for: article.id) }
        }
    }

    func remove(_ article: Article) {
        saved.removeAll { $0.id == article.id }
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) where saved.indices.contains(index) {
            saved.remove(at: index)
        }
        persist()
    }

    /// Keeps a saved copy current when the reader opens a fresher version of the story.
    func refresh(with article: Article) {
        guard article.contentHTML != nil,
              let index = saved.firstIndex(where: { $0.id == article.id }),
              saved[index] != article
        else { return }
        saved[index] = article
        persist()
    }

    private func fetchBody(for id: Int) async {
        guard let full = try? await api.post(id: id) else { return }
        refresh(with: full)
    }

    private func persist() {
        DiskStore.documents.save(saved, named: fileName)
    }
}
