import AppKit

enum PasteboardManager {

    /// Saved pasteboard data for restore after hyperlink paste.
    private static var savedItems: [[NSPasteboard.PasteboardType: Data]]?

    // MARK: - Read

    static func getPlainText() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    // MARK: - Save / Restore

    /// Deep-copies every item on the general pasteboard so we can restore later.
    static func saveState() {
        let pasteboard = NSPasteboard.general
        savedItems = pasteboard.pasteboardItems?.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    /// Writes the previously saved items back to the general pasteboard.
    static func restoreState() {
        guard let items = savedItems else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        for dict in items {
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }

        savedItems = nil
    }
}
