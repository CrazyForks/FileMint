import Foundation

public enum ClipboardTextError: Error, Equatable {
    case unsupported, empty, tooLarge
}

public enum ClipboardTextPolicy {
    public static let maximumUTF8Bytes = 8 * 1024 * 1024

    public static func validate(_ text: String?, itemCount: Int, hasFileReference: Bool) throws -> String {
        guard itemCount == 1, !hasFileReference else { throw ClipboardTextError.unsupported }
        guard let text, !text.isEmpty else { throw ClipboardTextError.empty }
        guard text.utf8.count <= maximumUTF8Bytes else { throw ClipboardTextError.tooLarge }
        return text
    }
}
