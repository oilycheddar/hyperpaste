import AppKit

enum RichTextBuilder {

    /// Writes a hyperlink to the general pasteboard.
    /// When `includeHTML` is true, writes HTML + RTF + plain text (needed for Chrome/Electron).
    /// When false, writes RTF + plain text only (native apps read RTF; web editors that
    /// don't support links fall back to plain text instead of stripping the HTML link).
    static func writeHyperlink(text: String, url: String, includeHTML: Bool = true) {
        guard let urlObj = URL(string: url) else { return }

        // --- HTML representation ---
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        let escapedURL = url
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        let html = "<meta charset=\"utf-8\"><a href=\"\(escapedURL)\">\(escapedText)</a>"

        // --- RTF representation ---
        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(.link, value: urlObj, range: fullRange)
        attributed.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.systemFontSize), range: fullRange)

        let rtfData = try? attributed.data(
            from: fullRange,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )

        // --- Write all representations via NSPasteboardItem ---
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let item = NSPasteboardItem()
        if includeHTML {
            item.setString(html, forType: .html)
        }
        if let rtf = rtfData {
            item.setData(rtf, forType: .rtf)
        }
        // Plain text fallback = the original URL (normal paste behavior for plain-text apps)
        item.setString(url, forType: .string)

        pasteboard.writeObjects([item])
    }
}
