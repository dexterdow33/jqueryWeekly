import SwiftUI

struct SavedView: View {
    @Environment(Library.self) private var library
    @Environment(SectionStore.self) private var sections

    var body: some View {
        NavigationStack {
            Group {
                if library.saved.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing saved yet", systemImage: "bookmark")
                    } description: {
                        Text("Tap the bookmark on any story to keep it here. Saved stories open without a connection.")
                    }
                } else {
                    List {
                        ForEach(library.saved) { article in
                            NavigationLink(value: Route.article(article)) {
                                ArticleRow(article: article, kicker: sections.kicker(for: article))
                            }
                            .listRowBackground(Color.gsrPaper)
                        }
                        .onDelete { offsets in
                            library.remove(atOffsets: offsets)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.gsrPaper)
                    .toolbar { EditButton() }
                }
            }
            .navigationTitle("Saved")
            .gsrDestinations()
        }
    }
}
