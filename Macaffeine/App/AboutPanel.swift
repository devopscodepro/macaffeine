import AppKit

@MainActor
enum AboutPanel {
    static let website = URL(string: "https://devopscode.pro")!
    static let repository = URL(string: "https://github.com/devopscodepro/macaffeine")!

    static func show() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits()])
    }

    // icon, name, version and copyright come from the bundle, only the credits are ours
    private static func credits() -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = 2
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style,
        ]

        let text = NSMutableAttributedString(string: String(localized: "Made by Aleksei Popov") + "\n", attributes: base)
        text.append(link("devopscode.pro", to: website, base: base))
        text.append(NSAttributedString(string: "  ·  ", attributes: base))
        text.append(link("GitHub", to: repository, base: base))
        return text
    }

    private static func link(_ title: String, to url: URL, base: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var attributes = base
        attributes[.link] = url
        return NSAttributedString(string: title, attributes: attributes)
    }
}
