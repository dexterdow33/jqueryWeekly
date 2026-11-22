import SafariServices
import SwiftUI

/// A web page shown inside the app with Safari's own view.
struct BrowserPage: Identifiable {
    let url: URL
    var id: URL { url }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(hex: 0xB14A37)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Decides where a link goes: a story inside the app, a page in the in-app browser,
/// or out to Safari, Mail or Phone.
enum LinkTarget {
    case story(slug: String)
    case inApp(URL)
    case external(URL)

    static func resolve(_ url: URL) -> LinkTarget {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return .external(url)
        }
        if GSR.mustOpenExternally(url) {
            return .external(url)
        }
        if let slug = GSR.articleSlug(from: url) {
            return .story(slug: slug)
        }
        return .inApp(url)
    }
}
