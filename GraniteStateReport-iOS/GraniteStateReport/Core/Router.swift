import Foundation
import Observation

/// Places the app can push onto a navigation stack.
enum Route: Hashable {
    case article(Article)
    case post(id: Int)
    case slug(String)
    case category(NewsCategory)
}

enum AppTab: Hashable {
    case today, sections, listen, saved, search
}

/// Shared navigation state: which tab is showing, and any story a notification asked for.
@MainActor
@Observable
final class Router {
    static let shared = Router()

    var tab: AppTab = .today
    /// Set when the reader taps a new-story alert. The Today tab opens it and clears it.
    var pendingPostID: Int?

    func open(postID: Int) {
        tab = .today
        pendingPostID = postID
    }
}
