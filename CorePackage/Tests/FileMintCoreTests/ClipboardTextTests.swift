import FileMintCore
import Foundation
import Testing

@Suite("Clipboard text draft")
struct ClipboardTextTests {
    @Test("only an explicit single plain-text item is accepted verbatim")
    func textPolicy() throws {
        let content = "  中文 🪴\r\n{{fileName}}  \n"
        #expect(try ClipboardTextPolicy.validate(content, itemCount: 1, hasFileReference: false) == content)
        #expect(try ClipboardTextPolicy.validate("  \n", itemCount: 1, hasFileReference: false) == "  \n")
        #expect(throws: ClipboardTextError.empty) {
            try ClipboardTextPolicy.validate("", itemCount: 1, hasFileReference: false)
        }
        #expect(throws: ClipboardTextError.unsupported) {
            try ClipboardTextPolicy.validate(content, itemCount: 2, hasFileReference: false)
        }
        #expect(throws: ClipboardTextError.unsupported) {
            try ClipboardTextPolicy.validate(content, itemCount: 1, hasFileReference: true)
        }
        #expect(try ClipboardTextPolicy.validate(String(repeating: "a", count: ClipboardTextPolicy.maximumUTF8Bytes),
            itemCount: 1, hasFileReference: false).utf8.count == ClipboardTextPolicy.maximumUTF8Bytes)
        #expect(throws: ClipboardTextError.tooLarge) {
            try ClipboardTextPolicy.validate(String(repeating: "é", count: ClipboardTextPolicy.maximumUTF8Bytes / 2 + 1),
                itemCount: 1, hasFileReference: false)
        }
    }

    @Test("new text tickets are single use and preserve old image and template ticket decoding")
    func ticket() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("Destination", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [folder]
        let store = QuickCreationTicketStore(directory: root.appendingPathComponent("tickets"))
        let now = Date()
        let text = try store.enqueueClipboardText(directory: folder, now: now)
        #expect(try store.consume(text, preferences: preferences, now: now)?.resolvedIntent == .clipboardText)
        #expect(try store.consume(text, preferences: preferences, now: now) == nil)
        let image = try store.enqueueClipboardImage(directory: folder, now: now)
        #expect(try store.consume(image, preferences: preferences, now: now)?.resolvedIntent == .clipboardImage)
        let template = try store.enqueue(directory: folder, templateID: "plain-text", now: now)
        #expect(try store.consume(template, preferences: preferences, now: now)?.resolvedIntent == .template)
        let expired = try store.enqueueClipboardText(directory: folder, now: now)
        #expect(try store.consume(expired, preferences: preferences, now: now.addingTimeInterval(61)) == nil)
    }
}
