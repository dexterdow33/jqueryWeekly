import XCTest
@testable import GraniteStateReport

final class HTMLTextTests: XCTestCase {

    func testDecodesNumericAndNamedEntities() {
        XCTAssertEqual(HTMLText.decodeEntities("Kennedy&#8217;s New Hampshire"), "Kennedy\u{2019}s New Hampshire")
        XCTAssertEqual(HTMLText.decodeEntities("Law &amp; Courts"), "Law & Courts")
        XCTAssertEqual(HTMLText.decodeEntities("Route 1A&rsquo;s"), "Route 1A\u{2019}s")
        XCTAssertEqual(HTMLText.decodeEntities("&#x2014;"), "\u{2014}")
    }

    func testLeavesBareAmpersandsAlone() {
        XCTAssertEqual(HTMLText.decodeEntities("AT&T and R&D; done"), "AT&T and R&D; done")
        XCTAssertEqual(HTMLText.decodeEntities("ends with &"), "ends with &")
        XCTAssertEqual(HTMLText.decodeEntities("&unknown; stays"), "&unknown; stays")
    }

    func testPlainStripsTagsAndCollapsesWhitespace() {
        let html = "<p>The Fiscal Committee accepted\n the money on <strong>Nov. 20</strong>.</p>\n"
        XCTAssertEqual(HTMLText.plain(html), "The Fiscal Committee accepted the money on Nov. 20.")
    }

    func testPlainDropsStyleBlocks() {
        XCTAssertEqual(HTMLText.plain("<style>.a{color:red}</style><p>Text</p>"), "Text")
    }

    func testFindsNarrationURL() {
        let html = #"<div class="gsr-audio"><audio controls preload="none" src="https://granitestatereport.com/wp-content/uploads/2026/11/narration.mp3"></audio></div>"#
        XCTAssertEqual(HTMLText.firstAudioURL(in: html)?.absoluteString,
                       "https://granitestatereport.com/wp-content/uploads/2026/11/narration.mp3")
        XCTAssertNil(HTMLText.firstAudioURL(in: "<p>No audio here.</p>"))
    }

    func testFindsNarrationInSourceTag() {
        let html = #"<audio controls><source src="https://example.org/a.mp3?x=1&#038;y=2" type="audio/mpeg"></audio>"#
        XCTAssertEqual(HTMLText.firstAudioURL(in: html)?.absoluteString, "https://example.org/a.mp3?x=1&y=2")
    }
}

final class PostDecodingTests: XCTestCase {

    private let json = #"""
    [{"id":15996,"date_gmt":"2026-11-22T12:00:00","slug":"jfk-new-hampshire-nashua-1960-primary",
      "link":"https://granitestatereport.com/2026/11/22/jfk-new-hampshire-nashua-1960-primary/",
      "title":{"rendered":"He Stopped Here First: John F. Kennedy&#8217;s New Hampshire"},
      "excerpt":{"rendered":"<p>Sixty-three years after Dallas.</p>\n","protected":false},
      "categories":[920,8],
      "jetpack_featured_media_url":"https://i0.wp.com/granitestatereport.com/wp-content/uploads/2026/10/hero.jpg?fit=1200%2C630&quality=89&ssl=1"},
     {"id":2,"date_gmt":"2026-01-01T00:00:00","slug":"no-image","link":"https://granitestatereport.com/2026/01/01/no-image/",
      "title":{"rendered":"No image"},"jetpack_featured_media_url":""}]
    """#

    func testDecodesPostList() throws {
        let posts = try JSONDecoder().decode([PostDTO].self, from: Data(json.utf8))
        let articles = posts.compactMap { $0.article() }
        XCTAssertEqual(articles.count, 2)

        let first = articles[0]
        XCTAssertEqual(first.id, 15996)
        XCTAssertEqual(first.title, "He Stopped Here First: John F. Kennedy\u{2019}s New Hampshire")
        XCTAssertEqual(first.excerpt, "Sixty-three years after Dallas.")
        XCTAssertEqual(first.categoryIDs, [920, 8])
        XCTAssertNil(first.contentHTML)
        XCTAssertEqual(first.date.timeIntervalSince1970, 1_795_348_800, accuracy: 1)

        XCTAssertNil(articles[1].imageURL)
        XCTAssertEqual(articles[1].categoryIDs, [])
    }

    func testResizesCDNImages() throws {
        let posts = try JSONDecoder().decode([PostDTO].self, from: Data(json.utf8))
        let article = try XCTUnwrap(posts.first?.article())
        let resized = try XCTUnwrap(article.image(width: 320))
        XCTAssertEqual(resized.host, "i0.wp.com")
        XCTAssertTrue(resized.absoluteString.contains("w=320"))
        XCTAssertFalse(resized.absoluteString.contains("fit="))
    }

    func testArticleSurvivesSaveAndLoad() throws {
        let posts = try JSONDecoder().decode([PostDTO].self, from: Data(json.utf8))
        let article = try XCTUnwrap(posts.first?.article())
        let data = try JSONEncoder().encode([article])
        XCTAssertEqual(try JSONDecoder().decode([Article].self, from: data), [article])
    }
}

final class LinkRoutingTests: XCTestCase {

    func testRecognizesArticlePermalinks() {
        let url = URL(string: "https://granitestatereport.com/2026/11/20/nh-climate-plan-no-binding-target/")!
        XCTAssertEqual(GSR.articleSlug(from: url), "nh-climate-plan-no-binding-target")
        XCTAssertEqual(GSR.articleSlug(from: URL(string: "https://www.granitestatereport.com/2026/11/20/a-b")!), "a-b")
    }

    func testPagesAndOtherSitesAreNotArticles() {
        XCTAssertNil(GSR.articleSlug(from: URL(string: "https://granitestatereport.com/about/")!))
        XCTAssertNil(GSR.articleSlug(from: URL(string: "https://granitestatereport.com/2026/11/")!))
        XCTAssertNil(GSR.articleSlug(from: URL(string: "https://example.org/2026/11/20/story/")!))
    }

    func testMoneyPagesLeaveTheApp() {
        guard case .external = LinkTarget.resolve(GSR.page("support")) else {
            return XCTFail("Support must open in Safari")
        }
        guard case .external = LinkTarget.resolve(URL(string: "mailto:granitestatereport@gmail.com")!) else {
            return XCTFail("Mail links must leave the app")
        }
        guard case .inApp = LinkTarget.resolve(GSR.page("about")) else {
            return XCTFail("Info pages open in the in-app browser")
        }
        guard case .story(let slug) = LinkTarget.resolve(URL(string: "https://granitestatereport.com/2026/11/20/some-story/")!) else {
            return XCTFail("Article links open in the reader")
        }
        XCTAssertEqual(slug, "some-story")
    }

    func testPageURLs() {
        XCTAssertEqual(GSR.page("privacy-policy").absoluteString, "https://granitestatereport.com/privacy-policy/")
    }
}
