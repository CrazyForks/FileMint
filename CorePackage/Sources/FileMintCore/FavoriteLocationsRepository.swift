import Foundation

public struct FavoriteLocationsSnapshot: Sendable {
    public let catalog: FavoriteLocationsCatalog
    public let revision: UInt64
}

/// Each transaction loads, checks and publishes without suspension. Callers can
/// await disk work without allowing one catalog edit to overwrite another.
public actor FavoriteLocationsRepository {
    private let store: FavoriteLocationsStore
    private var catalog: FavoriteLocationsCatalog?
    private var revision: UInt64 = 0

    public init(store: FavoriteLocationsStore = FavoriteLocationsStore()) { self.store = store }

    public func snapshot() throws -> FavoriteLocationsSnapshot {
        if catalog == nil { catalog = try store.load() }
        return FavoriteLocationsSnapshot(catalog: catalog!, revision: revision)
    }

    public func update<Result: Sendable>(
        _ edit: @Sendable (inout FavoriteLocationsCatalog) throws -> Result
    ) throws -> (Result, FavoriteLocationsSnapshot) {
        let previous = try snapshot().catalog
        guard let disk = try? store.load(), disk == previous else {
            throw FavoriteLocationError.damagedCatalog
        }
        var changed = previous
        let result = try edit(&changed)
        if changed != previous {
            do { try store.save(changed) }
            catch { throw FavoriteLocationError.saveFailed }
            catalog = changed
            revision += 1
        }
        return (result, try snapshot())
    }

    public func backupAndReset() throws -> (URL, FavoriteLocationsSnapshot) {
        let backup = try store.backupDamagedAndReset()
        catalog = FavoriteLocationsCatalog()
        revision += 1
        return (backup, try snapshot())
    }
}
