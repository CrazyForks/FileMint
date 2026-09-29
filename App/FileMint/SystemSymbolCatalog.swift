import AppKit
import Foundation

/// A bundled list of names, never glyph files. AppKit resolves each image on this Mac.
enum SystemSymbolCatalog {
    static let featured = [
        "doc", "doc.text", "doc.richtext", "doc.badge.plus", "doc.on.doc", "doc.on.clipboard",
        "folder", "folder.fill", "tray", "archivebox", "paperclip", "link",
        "star", "heart", "bookmark", "tag", "flag", "pin",
        "photo", "photo.on.rectangle", "camera", "text.viewfinder", "tablecells", "curlybraces",
        "terminal", "chevron.left.forwardslash.chevron.right", "wrench.and.screwdriver", "gearshape", "slider.horizontal.3", "square.stack.3d.up",
        "arrow.right.square", "arrowshape.turn.up.right", "arrow.triangle.2.circlepath", "square.and.arrow.up", "trash", "checkmark.shield"
    ]

    static let names: [String] = {
        guard let url = Bundle.main.url(forResource: "SFSymbolNames", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return featured }
        let catalog = contents.split(whereSeparator: \.isNewline).map(String.init)
            .filter { !$0.hasPrefix("#") && !$0.isEmpty }
        let values = Set(catalog)
        return featured.filter { values.contains($0) } + catalog.filter { !featured.contains($0) }
    }()

    private static let restrictedNames: Set<String> = {
        guard let url = Bundle.main.url(forResource: "SFSymbolRestrictedNames", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return Set(contents.split(whereSeparator: \.isNewline).map(String.init)
            .filter { !$0.hasPrefix("#") && !$0.isEmpty })
    }()

    static func isRestricted(_ name: String) -> Bool { restrictedNames.contains(name) }

    static func matching(_ query: String) -> [String] {
        let terms = query.lowercased().split { $0 == " " || $0 == "." }
        guard !terms.isEmpty else { return names }
        return names.filter { name in terms.allSatisfy { name.localizedStandardContains(String($0)) } }
    }

    static func isAvailable(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }
}
