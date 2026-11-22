import Foundation

/// Site-wide constants. Everything the app knows about Granite State Report lives here,
/// so a change to the site (a new page slug, a new phone number) is a one-line edit.
enum GSR {
    static let name = "Granite State Report"
    static let tagline = "Documents First Reporting and Analysis"

    static let host = "granitestatereport.com"
    static let siteURL = URL(string: "https://granitestatereport.com")!
    static let apiBaseURL = URL(string: "https://granitestatereport.com/wp-json")!

    static let email = "granitestatereport@gmail.com"
    static let phoneDisplay = "603-931-9264"
    static let phoneURL = URL(string: "tel:+16039319264")!
    static let emailURL = URL(string: "mailto:granitestatereport@gmail.com")!

    /// Background refresh identifier. Must match BGTaskSchedulerPermittedIdentifiers in Info.plist.
    static let refreshTaskID = "com.granitestatereport.app.refresh"

    /// Tabs of the site's media catalog that the app does not show.
    /// "live" is third-party radio streams that GSR does not produce or carry.
    /// Remove "live" from this set to show them.
    static let hiddenMediaTabs: Set<String> = ["live"]

    static func page(_ slug: String) -> URL {
        siteURL.appendingPathComponent(slug, isDirectory: true)
    }

    /// Pages that take money. App Store rules require these to open in Safari, outside the app.
    static let externalOnlyPaths: [String] = [
        "/support", "/subscribe", "/sponsor-a-request", "/membership"
    ]

    static func isGSR(_ url: URL) -> Bool {
        guard let h = url.host?.lowercased() else { return false }
        return h == host || h == "www." + host
    }

    static func mustOpenExternally(_ url: URL) -> Bool {
        guard isGSR(url) else { return false }
        let path = url.path.lowercased()
        return externalOnlyPaths.contains { path.hasPrefix($0) }
    }

    /// Returns the post slug when the URL is a GSR article permalink (/YYYY/MM/DD/slug/).
    static func articleSlug(from url: URL) -> String? {
        guard isGSR(url) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count == 4,
              parts[0].count == 4, Int(parts[0]) != nil,
              parts[1].count == 2, Int(parts[1]) != nil,
              parts[2].count == 2, Int(parts[2]) != nil,
              !parts[3].isEmpty
        else { return nil }
        return parts[3]
    }
}
