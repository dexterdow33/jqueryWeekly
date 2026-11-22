import Foundation

/// Small, dependency-free helpers for the HTML that the WordPress REST API returns.
enum HTMLText {

    /// Tags stripped, entities decoded, whitespace collapsed. For titles and excerpts.
    static func plain(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(
            of: "<(style|script)[^>]*>[\\s\\S]*?</(style|script)>",
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        // Block tags become a space so words on either side stay apart; inline tags vanish
        // so "<strong>Nov. 20</strong>." does not gain a space before the period.
        text = text.replacingOccurrences(
            of: "</?(p|div|br|li|ul|ol|h[1-6]|tr|td|th|table|blockquote|figure|figcaption)\\b[^>]*>",
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeEntities(text)
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Decodes numeric entities and the named entities WordPress emits.
    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = ""
        result.reserveCapacity(string.count)
        var rest = Substring(string)
        while let amp = rest.firstIndex(of: "&") {
            result.append(contentsOf: rest[..<amp])
            let after = rest[rest.index(after: amp)...]
            if let semi = after.prefix(12).firstIndex(of: ";"),
               let decoded = decode(entity: String(after[..<semi])) {
                result.append(contentsOf: decoded)
                rest = after[after.index(after: semi)...]
            } else {
                result.append("&")
                rest = after
            }
        }
        result.append(contentsOf: rest)
        return result
    }

    private static func decode(entity: String) -> String? {
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            return scalar(UInt32(entity.dropFirst(2), radix: 16))
        }
        if entity.hasPrefix("#") {
            return scalar(UInt32(entity.dropFirst(1), radix: 10))
        }
        return named[entity]
    }

    private static func scalar(_ value: UInt32?) -> String? {
        guard let value, let scalar = Unicode.Scalar(value) else { return nil }
        return String(Character(scalar))
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "rsquo": "\u{2019}", "lsquo": "\u{2018}", "rdquo": "\u{201D}", "ldquo": "\u{201C}",
        "ndash": "\u{2013}", "mdash": "\u{2014}", "hellip": "\u{2026}", "middot": "\u{00B7}",
        "bull": "\u{2022}", "copy": "\u{00A9}", "reg": "\u{00AE}", "trade": "\u{2122}",
        "sect": "\u{00A7}", "para": "\u{00B6}", "deg": "\u{00B0}", "cent": "\u{00A2}",
        "frac12": "\u{00BD}", "frac14": "\u{00BC}", "frac34": "\u{00BE}", "times": "\u{00D7}",
        "eacute": "\u{00E9}", "egrave": "\u{00E8}", "aacute": "\u{00E1}", "ntilde": "\u{00F1}",
        "uuml": "\u{00FC}", "ouml": "\u{00F6}", "ccedil": "\u{00E7}", "prime": "\u{2032}"
    ]

    /// The first narration file in an article body, if the article has one.
    static func firstAudioURL(in html: String) -> URL? {
        firstMatch(in: html, pattern: "<audio[^>]*?\\ssrc\\s*=\\s*[\"']([^\"']+)[\"']")
            .or(firstMatch(in: html, pattern: "<audio[^>]*>\\s*<source[^>]*?\\ssrc\\s*=\\s*[\"']([^\"']+)[\"']"))
            .flatMap { URL(string: decodeEntities($0)) }
    }

    /// First capture group of the first match, or nil.
    static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[captured])
    }
}

private extension Optional {
    func or(_ other: @autoclosure () -> Wrapped?) -> Wrapped? {
        self ?? other()
    }
}
