import SwiftUI

struct SearchView: View {
    @State private var text = ""
    @State private var feed = FeedModel(query: .search(""))
    @AppStorage("recentSearches") private var recentStorage = ""

    private var recents: [String] {
        recentStorage.split(separator: "\n").map(String.init)
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if trimmed.count < 2 {
                    recentList
                } else {
                    FeedContent(feed: feed, emptyTitle: "No stories match \u{201C}\(trimmed)\u{201D}")
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color.gsrPaper)
            .navigationTitle("Search")
            .searchable(text: $text,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search Granite State Report")
            .autocorrectionDisabled()
            .onSubmit(of: .search) { remember(trimmed) }
            .gsrDestinations()
        }
        .task(id: trimmed) {
            let term = trimmed
            guard term.count >= 2 else {
                feed.setQuery(.search(""))
                return
            }
            // Wait for a pause in typing before asking the site.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            feed.setQuery(.search(term))
            await feed.reload()
        }
    }

    @ViewBuilder
    private var recentList: some View {
        if recents.isEmpty {
            ContentUnavailableView {
                Label("Search the archive", systemImage: "magnifyingglass")
            } description: {
                Text("Find stories by name, town, agency, bill number or topic.")
            }
            .padding(.top, 60)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Kicker(text: "Recent searches")
                    Spacer()
                    Button("Clear") { recentStorage = "" }
                        .font(.footnote)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ForEach(recents, id: \.self) { term in
                    Button {
                        text = term
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(Color.gsrMuted)
                            Text(term)
                                .foregroundStyle(Color.gsrInk)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Hairline().padding(.leading, 16)
                }
            }
        }
    }

    private func remember(_ term: String) {
        guard term.count >= 2 else { return }
        var list = recents.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        list.insert(term.replacingOccurrences(of: "\n", with: " "), at: 0)
        recentStorage = list.prefix(8).joined(separator: "\n")
    }
}
