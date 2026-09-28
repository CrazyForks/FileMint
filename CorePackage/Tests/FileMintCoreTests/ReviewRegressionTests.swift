import Darwin
import Foundation
import Testing
@testable import FileMintCore

@Suite("Review regressions")
struct ReviewRegressionTests {
    @Test("ordinary quit waits for every writer, independently of updater state")
    func quitSafety() {
        #expect(ApplicationTerminationPolicy.canQuit(pendingCreations: 0, hasActiveWrite: false,
            hasFileOperation: false, hasFavoriteOperation: false))
        #expect(!ApplicationTerminationPolicy.canQuit(pendingCreations: 1, hasActiveWrite: false,
            hasFileOperation: false, hasFavoriteOperation: false))
        #expect(!ApplicationTerminationPolicy.canQuit(pendingCreations: 0, hasActiveWrite: true,
            hasFileOperation: false, hasFavoriteOperation: false))
        #expect(!ApplicationTerminationPolicy.canQuit(pendingCreations: 0, hasActiveWrite: false,
            hasFileOperation: true, hasFavoriteOperation: false))
        #expect(!ApplicationTerminationPolicy.canQuit(pendingCreations: 0, hasActiveWrite: false,
            hasFileOperation: false, hasFavoriteOperation: true))
    }

    @Test("creation retains permission errors and still accepts directory symlinks")
    func creationPermissions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("creation-access-\(UUID())")
        let parent = root.appendingPathComponent("parent")
        let directory = parent.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { chmod(parent.path, 0o700); try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        let request = FileCreationRequest(destinationDirectory: link, template: TemplateCatalog.builtInTemplates[0])
        let created = try FileCreationService().createFile(request)
        #expect(FileManager.default.fileExists(atPath: created.createdURL.path))
        #expect(chmod(parent.path, 0) == 0)
        #expect(throws: (any Error).self) {
            do { _ = try FileCreationService().createFile(request) }
            catch {
                let failure = error as NSError
                #expect(failure.domain == NSPOSIXErrorDomain && failure.code == Int(EACCES))
                throw error
            }
        }
    }

    @Test("extreme imported ranks preserve templates and order without arithmetic traps")
    func importedRanks() throws {
        let types = [
            FileTemplate(id: "a", displayName: "First", suggestedFileName: "a.txt", group: "Custom",
                content: "a", rank: Int.max - 1),
            FileTemplate(id: "b", displayName: "Second", suggestedFileName: "b.txt", group: "Custom",
                content: "b", rank: Int.max)
        ]
        let preferences = FileMintPreferences(templates: types, monitoredFolderURLs: [], collisionStrategy: .fail,
            revealAfterCreation: false, favoritesFirst: false)
        let decoded = try FileMintPreferencesStore.decode(JSONEncoder().encode(preferences))
        #expect(Array(decoded.templates.prefix(2).map(\.id)) == ["a", "b"])
        #expect(Array(decoded.templates.prefix(2).map(\.content)) == ["a", "b"])
        #expect(decoded.monitoredFolderURLs.isEmpty && decoded.collisionStrategy == .fail)
        let new = try TemplateCatalog.customTemplate(name: "Next", fileExtension: "txt", content: "",
                                                     in: decoded.templates)
        #expect(new.rank > (decoded.templates.map(\.rank).max() ?? 0))
        #expect(throws: TemplateValidationError.self) { try TemplateCatalog.nextRank(in: types) }
    }
}
