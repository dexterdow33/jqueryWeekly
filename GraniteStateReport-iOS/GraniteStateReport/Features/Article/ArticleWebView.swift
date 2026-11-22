import SwiftUI
import WebKit

/// Shows one article body. Link taps and the listen block are handed back to SwiftUI;
/// the web view never navigates away from the story.
struct ArticleWebView: UIViewRepresentable {
    let articleID: Int
    let html: String
    let textSize: Int
    var onLink: (URL) -> Void
    var onListen: () -> Void
    var onProgress: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.dataDetectorTypes = []
        configuration.userContentController.add(context.coordinator, name: "gsr")
        configuration.userContentController.addUserScript(
            WKUserScript(source: Coordinator.textSizeScript(textSize),
                         injectionTime: .atDocumentStart,
                         forMainFrameOnly: true)
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.isOpaque = true
        webView.allowsLinkPreview = true
        webView.allowsBackForwardNavigationGestures = false

        context.coordinator.load(self, into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.loadedID != articleID || coordinator.loadedLength != html.utf8.count {
            coordinator.load(self, into: webView)
        } else if coordinator.appliedTextSize != textSize {
            coordinator.appliedTextSize = textSize
            webView.evaluateJavaScript(Coordinator.textSizeScript(textSize), completionHandler: nil)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.scrollView.delegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "gsr")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UIScrollViewDelegate {
        var parent: ArticleWebView
        var loadedID: Int?
        var loadedLength = 0
        var appliedTextSize = 100
        private var lastProgress: Double = -1

        init(_ parent: ArticleWebView) {
            self.parent = parent
        }

        static func textSizeScript(_ percent: Int) -> String {
            "document.documentElement.style.webkitTextSizeAdjust = '\(percent)%';"
        }

        func load(_ view: ArticleWebView, into webView: WKWebView) {
            loadedID = view.articleID
            loadedLength = view.html.utf8.count
            appliedTextSize = view.textSize
            lastProgress = -1
            webView.loadHTMLString(view.html, baseURL: GSR.siteURL)
        }

        // MARK: Navigation

        @MainActor
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }

            // Anything other than a tapped link may load only inside a frame or as the story itself.
            if navigationAction.navigationType != .linkActivated {
                let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
                let isOwnDocument = GSR.isGSR(url) && (url.path.isEmpty || url.path == "/")
                if !isMainFrame || isOwnDocument || url.scheme == "about" { return .allow }
                parent.onLink(url)
                return .cancel
            }

            // Footnote and in-page anchors stay in the page.
            if url.fragment != nil, GSR.isGSR(url), url.path.isEmpty || url.path == "/" {
                return .allow
            }
            parent.onLink(url)
            return .cancel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // The size set at document start can be lost on some pages; set it again once loaded.
            webView.evaluateJavaScript(Coordinator.textSizeScript(appliedTextSize), completionHandler: nil)
        }

        /// iOS can end the page's process to free memory, often while audio plays. Put the story back.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            load(parent, into: webView)
        }

        /// Links that ask for a new window (target="_blank") arrive here.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                parent.onLink(url)
            }
            return nil
        }

        // MARK: Listen block

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "gsr", (message.body as? String) == "listen" {
                parent.onListen()
            }
        }

        // MARK: Reading progress

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let inset = scrollView.adjustedContentInset
            let scrollable = scrollView.contentSize.height + inset.top + inset.bottom - scrollView.bounds.height
            guard scrollable > 1 else { return }
            let offset = scrollView.contentOffset.y + inset.top
            let progress = min(max(Double(offset / scrollable), 0), 1)
            if abs(progress - lastProgress) >= 0.004 {
                lastProgress = progress
                parent.onProgress(progress)
            }
        }
    }
}
