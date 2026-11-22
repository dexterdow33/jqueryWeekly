import Observation
import SwiftUI
import UIKit

struct ArticleView: View {
    enum Source: Hashable {
        case article(Article)
        case id(Int)
        case slug(String)
    }

    let source: Source

    @Environment(Library.self) private var library
    @Environment(AudioPlayer.self) private var player
    @Environment(\.openURL) private var openURL
    @AppStorage("articleTextSize") private var textSize = 100

    @State private var article: Article?
    @State private var page: Page?
    @State private var errorMessage: String?
    @State private var reading = ReadingProgress()
    @State private var webPage: BrowserPage?
    @State private var linkedSlug: String?

    var body: some View {
        Group {
            if let page {
                ArticleWebView(
                    articleID: page.id,
                    html: page.html,
                    textSize: textSize,
                    onLink: { open($0) },
                    onListen: { listen() },
                    onProgress: { [reading] value in reading.fraction = value }
                )
                .overlay(alignment: .top) { ReadingProgressBar(reading: reading) }
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load this story", systemImage: "wifi.slash")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again") {
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task { await load() }
        .navigationDestination(item: $linkedSlug) { slug in
            ArticleView(source: .slug(slug))
        }
        .fullScreenCover(item: $webPage) { page in
            SafariView(url: page.url)
                .ignoresSafeArea()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let article {
                if page?.narration != nil {
                    Button {
                        listen()
                    } label: {
                        Image(systemName: "headphones")
                    }
                    .accessibilityLabel("Listen to this article")
                }

                Button {
                    library.toggle(article)
                } label: {
                    Image(systemName: library.isSaved(article) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(library.isSaved(article) ? "Remove from Saved" : "Save for later")

                Menu {
                    ShareLink(item: article.link, subject: Text(article.title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Section("Text Size") {
                        Button {
                            stepTextSize(by: 1)
                        } label: {
                            Label("Larger", systemImage: "textformat.size.larger")
                        }
                        .disabled(textSize >= (ArticleHTML.textSizes.last ?? 150))
                        Button {
                            stepTextSize(by: -1)
                        } label: {
                            Label("Smaller", systemImage: "textformat.size.smaller")
                        }
                        .disabled(textSize <= (ArticleHTML.textSizes.first ?? 85))
                    }
                    Section {
                        Button {
                            openURL(article.link)
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                        }
                        Button {
                            UIPasteboard.general.url = article.link
                        } label: {
                            Label("Copy Link", systemImage: "link")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
    }

    // MARK: Actions

    private func stepTextSize(by step: Int) {
        let sizes = ArticleHTML.textSizes
        let index = sizes.firstIndex(of: textSize) ?? 1
        textSize = sizes[min(max(index + step, 0), sizes.count - 1)]
    }

    private func listen() {
        guard let article, let url = page?.narration else { return }
        let track = AudioTrack(url: url, title: article.title, subtitle: "Article narration", link: article.link)
        if player.current == track {
            player.toggle()
        } else {
            player.play(track, queue: [track])
        }
    }

    private func open(_ url: URL) {
        switch LinkTarget.resolve(url) {
        case .story(let slug):
            linkedSlug = slug
        case .inApp(let page):
            webPage = BrowserPage(url: page)
        case .external(let destination):
            openURL(destination)
        }
    }

    // MARK: Loading

    /// Puts a story on screen. The page is built once here, not on every redraw.
    private func show(_ story: Article) {
        article = story
        guard let body = story.contentHTML else { return }
        if let page, page.id == story.id, page.body == body { return }
        let narration = story.audioURL
        page = Page(id: story.id,
                    body: body,
                    html: ArticleHTML.document(body: body, nativeAudio: narration != nil),
                    narration: narration)
    }

    private func load() async {
        errorMessage = nil

        // Show whatever is already on hand, then fetch the current version.
        if page == nil {
            switch source {
            case .article(let given):
                show(given.contentHTML != nil ? given : (library.savedCopy(id: given.id) ?? given))
            case .id(let id):
                if let copy = library.savedCopy(id: id) { show(copy) }
            case .slug(let slug):
                if let copy = library.savedCopy(slug: slug) { show(copy) }
            }
        }

        do {
            let fresh: Article
            switch source {
            case .article(let given):
                fresh = try await WordPressAPI.shared.post(id: given.id)
            case .id(let id):
                fresh = try await WordPressAPI.shared.post(id: id)
            case .slug(let slug):
                fresh = try await WordPressAPI.shared.post(slug: slug)
            }
            show(fresh)
            library.refresh(with: fresh)
        } catch is CancellationError {
            return
        } catch {
            if page == nil {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// A story prepared for the reader.
private struct Page {
    let id: Int
    let body: String
    let html: String
    let narration: URL?
}

/// How far down the story the reader is. Kept apart from the article view so scrolling
/// redraws only the thin bar that shows it.
@MainActor
@Observable
final class ReadingProgress {
    var fraction: Double = 0
}

private struct ReadingProgressBar: View {
    let reading: ReadingProgress

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.gsrBrick)
                .frame(width: geometry.size.width * reading.fraction, height: 2.5)
        }
        .frame(height: 2.5)
        .accessibilityHidden(true)
    }
}
