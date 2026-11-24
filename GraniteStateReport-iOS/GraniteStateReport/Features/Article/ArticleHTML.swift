import Foundation

/// Wraps an article body from the site in a page the in-app reader can show.
/// The body carries GSR's own article template and styles; this adds only what a phone needs.
enum ArticleHTML {
    static let textSizes = [85, 100, 115, 130, 150]

    static func document(body: String, nativeAudio: Bool) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <meta name="color-scheme" content="light">
        <style>
        html, body { margin: 0; padding: 0; background: #ffffff; }
        body { overflow-wrap: break-word; -webkit-touch-callout: default; }
        html body .gsr-article { box-shadow: none !important; }
        html body img, html body video, html body iframe { max-width: 100% !important; }
        html body .gsr-article img { height: auto !important; }
        html body .gsr-article table { max-width: 100% !important; }
        \(nativeAudio ? audioStyles : "")
        </style>
        </head>
        <body>
        \(body)
        \(nativeAudio ? audioScript : "")
        </body>
        </html>
        """
    }

    /// When the app's own player handles narration, the web audio control is hidden and the
    /// "Listen to this article" block becomes the play button. The synthetic-voice note stays visible.
    private static let audioStyles = """
    html body .gsr-article .gsr-audio audio { display: none !important; }
    html body .gsr-article .gsr-audio { cursor: pointer !important; -webkit-tap-highlight-color: rgba(177,74,55,.15); }
    html body .gsr-article .gsr-audio-label::before { content: "\\25B6\\FE0E\\00A0\\00A0"; }
    """

    private static let audioScript = """
    <script>
    document.addEventListener('click', function (event) {
      var block = event.target && event.target.closest ? event.target.closest('.gsr-audio') : null;
      if (!block) { return; }
      event.preventDefault();
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.gsr) {
        window.webkit.messageHandlers.gsr.postMessage('listen');
      }
    });
    </script>
    """
}
