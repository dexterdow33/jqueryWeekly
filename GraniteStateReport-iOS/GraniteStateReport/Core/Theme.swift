import SwiftUI
import UIKit

// The palette comes from the site's article template: navy #1A2E4A, brick #B14A37,
// warm paper, and a tan rule. Dark variants keep the same character at night.
extension Color {
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Headlines and primary ink.
    static let gsrInk = adaptive(light: 0x1A2E4A, dark: 0xE9EDF3)
    /// The brick accent: kickers, links, controls.
    static let gsrBrick = adaptive(light: 0xB14A37, dark: 0xE07A64)
    /// Body copy.
    static let gsrBody = adaptive(light: 0x23211E, dark: 0xD6D3CD)
    /// Datelines and secondary text.
    static let gsrMuted = adaptive(light: 0x5C574E, dark: 0x9C978E)
    /// Page background.
    static let gsrPaper = adaptive(light: 0xFBFAF7, dark: 0x101317)
    /// Cards and bars that sit on the page.
    static let gsrSurface = adaptive(light: 0xFFFFFF, dark: 0x1A1E24)
    /// Hairlines.
    static let gsrRule = adaptive(light: 0xD9D2C6, dark: 0x2E333B)
    /// Image slots before the image arrives.
    static let gsrPlaceholder = adaptive(light: 0xECE8E0, dark: 0x22272E)
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Font {
    /// Georgia, the face the site sets its articles in. Scales with Dynamic Type.
    static func gsrSerif(_ size: CGFloat, bold: Bool = true, relativeTo style: Font.TextStyle = .title3) -> Font {
        .custom(bold ? "Georgia-Bold" : "Georgia", size: size, relativeTo: style)
    }
}

/// The small brick label above a headline.
struct Kicker: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(Color.gsrBrick)
            .lineLimit(1)
    }
}

/// A full-width hairline in the house rule color.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.gsrRule)
            .frame(height: 1)
    }
}

extension Date {
    /// "3 hours ago" for the last day, a plain date after that.
    var gsrDateline: String {
        let age = Date().timeIntervalSince(self)
        if age >= 0, age < 24 * 60 * 60 {
            return self.formatted(.relative(presentation: .named))
        }
        return self.formatted(date: .abbreviated, time: .omitted)
    }
}
