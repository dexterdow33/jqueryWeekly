import SwiftUI

/// The front-page treatment for the newest story.
struct LeadStoryCard: View {
    let article: Article
    let kicker: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if article.imageURL != nil {
                RemoteImage(url: article.image(width: 1200))
                    .aspectRatio(1200.0 / 630.0, contentMode: .fit)
            }
            VStack(alignment: .leading, spacing: 9) {
                if let kicker {
                    Kicker(text: kicker)
                }
                Text(article.title)
                    .font(.gsrSerif(27, relativeTo: .title))
                    .foregroundStyle(Color.gsrInk)
                    .fixedSize(horizontal: false, vertical: true)
                if !article.excerpt.isEmpty {
                    Text(article.excerpt)
                        .font(.gsrSerif(17, bold: false, relativeTo: .body))
                        .foregroundStyle(Color.gsrBody)
                        .lineSpacing(3)
                        .lineLimit(5)
                }
                Text(article.date.gsrDateline)
                    .font(.caption)
                    .foregroundStyle(Color.gsrMuted)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A story in a list: headline on the left, picture on the right.
struct ArticleRow: View {
    let article: Article
    let kicker: String?
    var showsSavedMark = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                if let kicker {
                    Kicker(text: kicker)
                }
                Text(article.title)
                    .font(.gsrSerif(18, relativeTo: .headline))
                    .foregroundStyle(Color.gsrInk)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text(article.date.gsrDateline)
                    if showsSavedMark {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(Color.gsrBrick)
                            .accessibilityLabel("Saved")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.gsrMuted)
            }
            Spacer(minLength: 0)
            if article.imageURL != nil {
                RemoteImage(url: article.image(width: 320))
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Save and share, for long-press menus.
struct ArticleMenuItems: View {
    let article: Article
    @Environment(Library.self) private var library

    var body: some View {
        Button {
            library.toggle(article)
        } label: {
            if library.isSaved(article) {
                Label("Remove from Saved", systemImage: "bookmark.slash")
            } else {
                Label("Save for Later", systemImage: "bookmark")
            }
        }
        ShareLink(item: article.link, subject: Text(article.title)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}

/// The body of any feed screen: loading, error, empty, or the stories. Place inside a ScrollView.
struct FeedContent: View {
    let feed: FeedModel
    var showsLead = false
    var emptyTitle = "No stories here yet"

    @Environment(SectionStore.self) private var sections
    @Environment(Library.self) private var library

    var body: some View {
        if feed.articles.isEmpty {
            if let message = feed.errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load stories", systemImage: "wifi.slash")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") {
                        Task { await feed.reload() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 60)
            } else if feed.hasLoaded {
                ContentUnavailableView(emptyTitle, systemImage: "newspaper")
                    .padding(.top, 60)
            } else {
                FeedSkeleton()
            }
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                if feed.isShowingCache {
                    Label("Offline. Showing the last stories loaded.", systemImage: "wifi.slash")
                        .font(.footnote)
                        .foregroundStyle(Color.gsrMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                ForEach(Array(feed.articles.enumerated()), id: \.element.id) { index, article in
                    let isLead = showsLead && index == 0
                    NavigationLink(value: Route.article(article)) {
                        if isLead {
                            LeadStoryCard(article: article, kicker: sections.kicker(for: article))
                        } else {
                            ArticleRow(article: article,
                                       kicker: sections.kicker(for: article),
                                       showsSavedMark: library.isSaved(article))
                                .padding(.horizontal, 16)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu { ArticleMenuItems(article: article) }
                    .onAppear {
                        Task { await feed.loadMoreIfNeeded(after: article) }
                    }

                    Hairline()
                        .padding(.horizontal, isLead ? 0 : 16)
                }
                if feed.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
    }
}

/// Grey placeholder rows while the first page loads.
struct FeedSkeleton: View {
    private let sample = Article(
        id: 0,
        date: Date(timeIntervalSince1970: 0),
        slug: "",
        link: GSR.siteURL,
        title: "A headline about New Hampshire that runs to a second line",
        excerpt: "",
        imageURL: nil,
        categoryIDs: [],
        contentHTML: nil
    )

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { _ in
                HStack(alignment: .top, spacing: 14) {
                    ArticleRow(article: sample, kicker: "Section")
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.gsrPlaceholder)
                        .frame(width: 92, height: 92)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 16)
                Hairline().padding(.horizontal, 16)
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}
