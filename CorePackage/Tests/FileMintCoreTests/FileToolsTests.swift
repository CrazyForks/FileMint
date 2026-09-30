import FileMintCore
import Foundation
import Testing

@Suite("Optional file and folder tools")
struct FileToolsTests {
    private let root = URL(fileURLWithPath: "/Users/example/Work", isDirectory: true)

    private func enabledPreferences() -> FileMintPreferences {
        var value = FileMintPreferences.default
        value.monitoredFolderURLs = [root]
        value.fileTools.isEnabled = true
        return value
    }

    @Test("legacy settings keep creation choices and leave the module off")
    func migration() throws {
        let value = try JSONDecoder().decode(FileMintPreferences.self,
            from: Data(#"{"language":"zh-Hans","revealAfterCreation":false,"collisionStrategy":"fail"}"#.utf8))
        #expect(!value.fileTools.isEnabled)
        #expect(value.fileTools.copyNames && value.fileTools.copyPaths)
        #expect(value.language == .chinese && !value.revealAfterCreation)
        #expect(value.collisionStrategy == .fail)
        let partial = try JSONDecoder().decode(FileToolsPreferences.self,
            from: Data(#"{"isEnabled":true,"copyNames":false}"#.utf8))
        #expect(partial.isEnabled && !partial.copyNames && partial.copyPaths)
    }

    @Test("master off preserves child choices across persistence and empty menus disappear")
    func toggles() throws {
        var value = enabledPreferences()
        let files = [root.appendingPathComponent("note.txt")]
        value.fileTools.copyPaths = false
        value.fileTools.move = false
        #expect(FileToolsPolicy.availableTools(selection: files, isItemMenu: true, preferences: value) == [.copyNames])
        value.fileTools.isEnabled = false
        value = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(value))
        #expect(value.fileTools.copyNames && !value.fileTools.copyPaths)
        #expect(FileToolsPolicy.availableTools(selection: files, isItemMenu: true, preferences: value).isEmpty)
        value.fileTools.isEnabled = true
        #expect(FileToolsPolicy.availableTools(selection: files, isItemMenu: true, preferences: value) == [.copyNames])
        value.fileTools.copyNames = false
        #expect(FileToolsPolicy.availableTools(selection: files, isItemMenu: true, preferences: value).isEmpty)
    }

    @Test("selection tools require a whole valid item-menu selection in scope")
    func menuScope() {
        let value = enabledPreferences()
        let item = root.appendingPathComponent("文件夹", isDirectory: true)
        #expect(FileToolsPolicy.availableTools(selection: [item], isItemMenu: true, preferences: value) == [.copyNames, .copyPaths, .move])
        #expect(FileToolsPolicy.availableTools(selection: [item], isItemMenu: false, preferences: value).isEmpty)
        #expect(FileToolsPolicy.availableTools(selection: [], isItemMenu: true, preferences: value).isEmpty)
        for other in [URL(fileURLWithPath: "/Users/example/Work-Other/a.txt"),
                      URL(string: "https://example.com/a.txt")!] {
            #expect(FileToolsPolicy.availableTools(selection: [item, other], isItemMenu: true, preferences: value).isEmpty)
        }
    }

    @Test("background Copy Paths captures the current folder and ignores stale selections")
    func backgroundTarget() throws {
        var value = enabledPreferences()
        for tool in FileTool.allCases { value.fileTools.setEnabled(true, for: tool) }
        let stale = URL(fileURLWithPath: "/Users/example/Elsewhere/old.txt")
        // A container callback needs no metadata, including at a configured root.
        let current = URL(fileURLWithPath: root.path)
        let target = try #require(FileToolsPolicy.target(directory: current, selection: [stale],
            isItemMenu: false, isContainer: true))
        #expect(target == .directory(current))
        #expect(FileToolsPolicy.availableTools(target: target, preferences: value) == [.copyPaths])
        #expect(FileToolsPolicy.clipboardText(for: .copyPaths, target: target) == "/Users/example/Work")
        for tool in FileTool.allCases where tool != .copyPaths {
            #expect(FileToolsPolicy.clipboardText(for: tool, target: target) == nil)
        }
        let nested = root.appendingPathComponent("资料 % 🪴", isDirectory: true)
        #expect(FileToolsPolicy.availableTools(target: .directory(nested), preferences: value) == [.copyPaths])
        #expect(FileToolsPolicy.clipboardText(for: .copyPaths, target: .directory(nested)) == "/Users/example/Work/资料 % 🪴")
    }

    @Test("toolbar, sidebar, empty item and out-of-scope contexts cannot become background targets")
    func invalidBackgroundContexts() {
        let value = enabledPreferences()
        let item = root.appendingPathComponent("note.txt")
        #expect(FileToolsPolicy.target(directory: root, selection: [item],
            isItemMenu: false, isContainer: false) == nil)
        #expect(FileToolsPolicy.target(directory: root, selection: [],
            isItemMenu: true, isContainer: false) == nil)
        #expect(FileToolsPolicy.target(directory: root, selection: [item],
            isItemMenu: true, isContainer: false) == .selection([item]))
        for directory in [URL(fileURLWithPath: "/Users/example/Work-Other", isDirectory: true),
                          URL(string: "https://example.com/Work/")!] {
            #expect(FileToolsPolicy.availableTools(target: .directory(directory), preferences: value).isEmpty)
        }
        let outside = URL(fileURLWithPath: "/Users/example/Elsewhere/old.txt")
        #expect(FileToolsPolicy.availableTools(target: .selection([item, outside]), preferences: value).isEmpty)
    }

    @Test("background menu placement follows Copy Paths and revoked choices reject old actions")
    func backgroundPreferences() {
        var value = enabledPreferences()
        let target = FileToolTarget.directory(root)
        func layout() -> FileToolsMenuLayout {
            FileToolsMenuLayout(tools: FileToolsPolicy.availableTools(target: target, preferences: value),
                hasMoveDestination: false, preferences: value.fileTools)
        }
        #expect(layout().main.isEmpty && layout().submenu == [.copyPaths] && layout().showsSubmenu)
        value.fileTools.mainMenuTools.insert(.copyPaths)
        #expect(layout().main == [.copyPaths] && !layout().showsSubmenu)
        value.fileTools.copyPaths = false
        #expect(layout().main.isEmpty && !layout().showsSubmenu)
        value.fileTools.copyPaths = true
        value.fileTools.isEnabled = false
        #expect(FileToolsPolicy.availableTools(target: target, preferences: value).isEmpty)
        value.fileTools.isEnabled = true
        value.monitoredFolderURLs = [root.appendingPathComponent("child", isDirectory: true)]
        #expect(FileToolsPolicy.availableTools(target: target, preferences: value).isEmpty)
    }

    @Test("overlapping background menus retain their original directory and consume once")
    func capturedBackgroundActions() throws {
        var registry = FileMenuActionRegistry()
        let first = registry.register([FileMenuAction(directory: root, tool: .copyPaths,
            target: .directory(root))])[0]
        let later = root.appendingPathComponent("Later", isDirectory: true)
        _ = registry.register([FileMenuAction(directory: later, tool: .copyPaths,
            target: .directory(later))])
        let firstAction = registry.takeAction(for: first)
        let captured = try #require(firstAction)
        let target = try #require(captured.fileToolTarget)
        #expect(captured.selection.isEmpty)
        #expect(target == .directory(root))
        #expect(FileToolsPolicy.clipboardText(for: .copyPaths, target: target) == "/Users/example/Work")
        let consumed = registry.takeAction(for: first)
        #expect(consumed == nil)
    }

    @Test("names and paths preserve order, extensions, Unicode, spaces and literal characters")
    func clipboardOutput() {
        let items = [root.appendingPathComponent("说明 文档.tar.gz"),
                     root.appendingPathComponent("资料 % 🪴", isDirectory: true)]
        #expect(FileToolsPolicy.clipboardText(for: .copyNames, selection: items) == "说明 文档.tar.gz\n资料 % 🪴")
        #expect(FileToolsPolicy.clipboardText(for: .copyPaths, selection: items) == "/Users/example/Work/说明 文档.tar.gz\n/Users/example/Work/资料 % 🪴")
    }

    @Test("overlapping menus retain their captured selections and disabled actions are rejected")
    func capturedActions() throws {
        var registry = FileMenuActionRegistry()
        var selection = [root.appendingPathComponent("first.txt")]
        let first = registry.register([FileMenuAction(directory: root, tool: .copyNames, selection: selection)])[0]
        selection = [root.appendingPathComponent("second.txt")]
        _ = registry.register([FileMenuAction(directory: root, tool: .copyNames, selection: selection)])
        let firstAction = registry.takeAction(for: first)
        let captured = try #require(firstAction)
        #expect(captured.selection.first?.lastPathComponent == "first.txt")
        let consumed = registry.takeAction(for: first)
        #expect(consumed == nil)
        var value = enabledPreferences()
        value.fileTools.copyNames = false
        #expect(!FileToolsPolicy.availableTools(selection: captured.selection, isItemMenu: true, preferences: value).contains(.copyNames))
        value.monitoredFolderURLs = []
        #expect(FileToolsPolicy.availableTools(selection: captured.selection, isItemMenu: true, preferences: value).isEmpty)
    }

    @Test("tool labels use the requested wording and have English translations")
    func labels() {
        #expect(FileMintStrings.text(.fileTools, language: .chinese) == "文件（夹）工具")
        #expect(FileMintStrings.text(.copyItemNames, language: .chinese) == "拷贝文件（夹）名称")
        for key in [FileMintTextKey.fileTools, .enableFileTools, .fileToolsHint, .copyItemNames,
                    .copyItemPaths, .copyItemsHint, .fileToolsOffHint, .clipboardWriteFailed, .extensions] {
            #expect(FileMintStrings.text(key, language: .english) != key.rawValue)
            #expect(FileMintStrings.text(key, language: .english) != FileMintStrings.text(key, language: .chinese))
        }
    }
}
