import AppKit
import FileMintCore

enum ClipboardTextReader {
    static func capture(from pasteboard: NSPasteboard) throws -> String {
        let items = pasteboard.pasteboardItems ?? []
        let item = items.count == 1 ? items[0] : nil
        let hasFileReference = item?.types.contains(.fileURL) == true ||
            item?.types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType")) == true
        return try ClipboardTextPolicy.validate(item?.string(forType: .string),
            itemCount: items.count, hasFileReference: hasFileReference)
    }
}
