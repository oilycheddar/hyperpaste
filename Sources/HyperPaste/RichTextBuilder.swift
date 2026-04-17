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

    /// Builds a minimal RTF hyperlink without trailing \par (which causes
    /// paragraph breaks when pasted as a fragment into Pages, Word, etc.).
    private static func buildRTF(text: String, url: String) -> Data? {
        let rtf = "{\\rtf1\\ansi {\\field{\\*\\fldinst{HYPERLINK \"\(rtfEscape(url))\"}}{\\fldrslt \(rtfEscape(text))}}}"
        return rtf.data(using: .utf8)
    }

    private static func rtfEscape(_ string: String) -> String {
        var result = ""
        for scalar in string.unicodeScalars {
            switch scalar.value {
            case 0x5C: result += "\\\\"
            case 0x7B: result += "\\{"
            case 0x7D: result += "\\}"
            case 0x20...0x7E: result += String(scalar)
            default:
                // RTF Unicode escape: \uN followed by a replacement char
                let code = Int32(bitPattern: UInt32(scalar.value))
                result += "\\u\(code)?"
            }
        }
        return result
    }
}
