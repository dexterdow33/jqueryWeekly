import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.tab) {
            TodayView()
                .miniPlayer()
                .tabItem { Label("Today", systemImage: "newspaper") }
                .tag(AppTab.today)

            SectionsView()
                .miniPlayer()
                .tabItem { Label("Sections", systemImage: "square.grid.2x2") }
                .tag(AppTab.sections)

            ListenView()
                .miniPlayer()
                .tabItem { Label("Listen", systemImage: "headphones") }
                .tag(AppTab.listen)

            SavedView()
                .miniPlayer()
                .tabItem { Label("Saved", systemImage: "bookmark") }
                .tag(AppTab.saved)

            SearchView()
                .miniPlayer()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)
        }
    }
}

extension View {
    /// Registers every screen a navigation stack in this app can push.
    func gsrDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .article(let article):
                ArticleView(source: .article(article))
            case .post(let id):
                ArticleView(source: .id(id))
            case .slug(let slug):
                ArticleView(source: .slug(slug))
            case .category(let category):
                CategoryFeedView(category: category)
            }
        }
    }
}
