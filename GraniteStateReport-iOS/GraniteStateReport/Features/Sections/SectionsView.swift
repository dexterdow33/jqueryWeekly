import SwiftUI

struct SectionsView: View {
    @Environment(SectionStore.self) private var sections

    var body: some View {
        NavigationStack {
            Group {
                if sections.categories.isEmpty {
                    if let message = sections.errorMessage {
                        ContentUnavailableView {
                            Label("Couldn't load sections", systemImage: "wifi.slash")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Try Again") {
                                Task { await sections.load(force: true) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ProgressView()
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Sections")
            .gsrDestinations()
        }
        .task { await sections.load() }
    }

    private var list: some View {
        List {
            ForEach(sections.topLevel) { category in
                Section {
                    NavigationLink(value: Route.category(category)) {
                        row(category, isParent: true)
                    }
                    ForEach(sections.children(of: category)) { child in
                        NavigationLink(value: Route.category(child)) {
                            row(child, isParent: false)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await sections.load(force: true) }
    }

    private func row(_ category: NewsCategory, isParent: Bool) -> some View {
        HStack {
            Text(category.name)
                .font(isParent ? .gsrSerif(19, relativeTo: .headline) : .body)
                .foregroundStyle(isParent ? Color.gsrInk : Color.gsrBody)
            Spacer()
            Text("\(category.count)")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Color.gsrMuted)
                .accessibilityLabel("\(category.count) stories")
        }
    }
}

struct CategoryFeedView: View {
    let category: NewsCategory

    @Environment(SectionStore.self) private var sections
    @State private var feed: FeedModel

    init(category: NewsCategory) {
        self.category = category
        _feed = State(initialValue: FeedModel(query: .category(category.id)))
    }

    var body: some View {
        let children = sections.children(of: category)

        ScrollView {
            VStack(spacing: 0) {
                if !children.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(children) { child in
                                NavigationLink(value: Route.category(child)) {
                                    Text(child.name)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.gsrSurface, in: Capsule())
                                        .overlay(Capsule().stroke(Color.gsrRule))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    Hairline()
                }
                FeedContent(feed: feed, showsLead: true, emptyTitle: "No stories in this section yet")
            }
        }
        .background(Color.gsrPaper)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await feed.refresh() }
        .task { await feed.loadIfNeeded() }
    }
}
