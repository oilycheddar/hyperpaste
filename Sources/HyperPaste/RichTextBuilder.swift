import AppKit

enum RichTextBuilder {

    /// Writes an HTML hyperlink, RTF hyperlink, and plain-text fallback to the general pasteboard.
    static func writeHyperlink(text: String, url: String) {
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

        // --- Write all representations ---
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Use declareTypes + setData/setString for multi-type write
        var types: [NSPasteboard.PasteboardType] = [.html, .string]
        if rtfData != nil { types.append(.rtf) }
        pasteboard.declareTypes(types, owner: nil)

        pasteboard.setString(html, forType: .html)
        if let rtf = rtfData {
            pasteboard.setData(rtf, forType: .rtf)
        }
        // Plain text fallback = the original URL (normal paste behavior for plain-text apps)
        pasteboard.setString(url, forType: .string)
    }
}
