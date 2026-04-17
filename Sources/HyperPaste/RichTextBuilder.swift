import AppKit

enum RichTextBuilder {

    /// Writes a hyperlink to the general pasteboard.
    /// When `includeHTML` is true, writes HTML + plain text (Chrome/Electron path).
    /// When false, writes RTF + plain text (native/Safari path).
    static func writeHyperlink(text: String, url: String, includeHTML: Bool = true) {
        guard URL(string: url) != nil else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let item = NSPasteboardItem()
        if includeHTML {
            item.setString(buildHTML(text: text, url: url), forType: .html)
        } else if let rtf = buildRTF(text: text, url: url) {
            item.setData(rtf, forType: .rtf)
        }
        item.setString(url, forType: .string)

        pasteboard.writeObjects([item])
    }

    // MARK: - HTML (Chrome/Electron)

    private static func buildHTML(text: String, url: String) -> String {
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        let escapedURL = url
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        return "<meta charset=\"utf-8\"><a href=\"\(escapedURL)\">\(escapedText)</a>"
    }

    // MARK: - RTF (native apps)

    /// Uses NSAttributedString to generate RTF (so Pages, Word, etc. can parse it)
    /// then strips the trailing \par that causes paragraph breaks when pasted.
    private static func buildRTF(text: String, url: String) -> Data? {
        guard let urlObj = URL(string: url) else { return nil }

        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(.link, value: urlObj, range: fullRange)
        attributed.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.systemFontSize), range: fullRange)

        guard let rtfData = try? attributed.data(
            from: fullRange,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else { return nil }

        // Strip trailing \par to prevent paragraph breaks when pasting as a fragment
        guard var rtfString = String(data: rtfData, encoding: .utf8) else { return rtfData }
        if let range = rtfString.range(of: "\\par", options: .backwards) {
            rtfString.removeSubrange(range)
        }
        return rtfString.data(using: .utf8) ?? rtfData
    }
}
