import AppKit
import FileMintCore

private struct SmokeFailure: Error { let message: String }

@main
@MainActor
struct FavoriteModelSmoke {
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw SmokeFailure(message: message) }
    }

    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMintFavoriteModel-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FavoriteLocationsStore(file: root.appendingPathComponent("catalog.json"))
        let entries = (0..<1000).map { index in
            FavoriteLocation(url: root.appendingPathComponent("item-\(index).txt"), bookmark: Data([1]),
                device: 1, inode: UInt64(index + 1), kind: .file, name: "Item \(index)",
                addedAt: Date(timeIntervalSince1970: Double(index)))
        }
        try store.save(FavoriteLocationsCatalog(items: entries))
        let model = FavoriteLocationsModel(store: store)
        try require(model.isLoading && model.catalog.items.isEmpty, "init performed synchronous catalog loading")
        await model.waitUntilLoaded()
        try require(model.catalog.items.count == 1000 && !model.isBusy, "initial snapshot did not load")
        let id = entries[10].id
        async let pinned: Void = model.setPinned([id], to: true)
        async let grouped: Void = model.setGroup([id], to: "工作")
        try await pinned
        try await grouped
        try require(model.catalog.items[10].isPinned && model.catalog.items[10].group == "工作", "concurrent edit was lost")
        try await model.updateDetails(id, name: "Renamed", group: "New group")
        try await model.clearRecent()
        try require(model.quickItems.map(\.id) == [id], "cleared history still appears")
        try require(try store.load() == model.catalog, "published snapshot differs from saved state")

        let selected = root.appendingPathComponent("selected.txt")
        try Data("fixture".utf8).write(to: selected)
        do {
            _ = try await model.add([selected], isAllowed: { false })
            throw SmokeFailure(message: "a revoked Finder policy was accepted")
        } catch FavoriteLocationError.invalidSelection {}
        try require(model.catalog.items.count == 1000 && !model.isBusy, "revoked add changed the catalog")

        let corrupt = Data("{broken".utf8)
        try corrupt.write(to: store.file)
        do {
            try await model.remove([id])
            throw SmokeFailure(message: "external corruption was overwritten")
        } catch FavoriteLocationError.damagedCatalog {}
        try require(model.recoveryRequired && model.catalog.items.count == 1000 && !model.isBusy,
                    "failed write discarded the visible snapshot or held the busy guard")
        await model.backupAndReset(language: .english)
        guard let backup = model.backupURL else { throw SmokeFailure(message: "recovery lost the backup") }
        try require(try Data(contentsOf: backup) == corrupt, "recovery changed damaged bytes")
        try require(model.catalog.items.isEmpty && !model.recoveryRequired && !model.isBusy, "recovery did not complete")
        print("PASS favorite model: async loading, 1000 entries, concurrent edits, cleared recents, damage recovery, busy guard")
    }
}
