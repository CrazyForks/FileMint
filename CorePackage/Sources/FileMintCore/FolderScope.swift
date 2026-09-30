import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum FolderScope {
    public enum DirectoryAccess: Equatable, Sendable {
        case allowed, requiresAuthorization, outsideScope
    }

    public static func contains(_ directory: URL, in folders: [URL]) -> Bool {
        guard directory.isFileURL else { return false }
        let target = directory.standardizedFileURL.path
        return folders.contains {
            guard $0.isFileURL else { return false }
            let root = $0.standardizedFileURL.path
            return target == root || target.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
    }

    /// Used by the writer after authorization. Finder's menu callback keeps the
    /// path-only check above because filesystem probes can fail in its sandbox.
    public static func containsResolvedDirectory(_ directory: URL, in folders: [URL]) -> Bool {
        guard let target = resolvedPath(directory) else { return false }
        return resolvedRoots(folders).contains { containsPath(target, in: $0) }
    }

    /// A permission failure is not evidence that an otherwise configured path is
    /// outside scope. It permits an exact-folder authorization prompt, never I/O.
    public static func directoryAccess(_ directory: URL, in folders: [URL]) -> DirectoryAccess {
        guard contains(directory, in: folders) else { return .outsideScope }
        let target: String
        do { target = try resolvingPath(directory) }
        catch { return isPermissionError(error) ? .requiresAuthorization : .outsideScope }
        var inaccessibleRoot = false
        for folder in folders where folder.isFileURL {
            do {
                if containsPath(target, in: try resolvingPath(folder)) { return .allowed }
            } catch {
                if contains(directory, in: [folder]), isPermissionError(error) { inaccessibleRoot = true }
            }
        }
        return inaccessibleRoot ? .requiresAuthorization : .outsideScope
    }

    /// A selected symlink is an entry in its parent, not its target. Resolve only
    /// the parent so removing or moving the link itself remains in scope.
    public static func containsResolvedItem(_ item: URL, in folders: [URL]) -> Bool {
        guard item.isFileURL, item.standardizedFileURL.path != "/",
              let parent = resolvedPath(item.deletingLastPathComponent()),
              !item.lastPathComponent.contains("/") else { return false }
        let target = (parent == "/" ? "" : parent) + "/" + item.lastPathComponent
        return resolvedRoots(folders).contains { containsPath(target, in: $0) }
    }

    private static func resolvedRoots(_ folders: [URL]) -> [String] {
        folders.compactMap(resolvedPath)
    }

    private static func containsPath(_ target: String, in root: String) -> Bool {
        target == root || target.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    private static func resolvedPath(_ url: URL) -> String? {
        try? resolvingPath(url)
    }

    private static func resolvingPath(_ url: URL) throws -> String {
        guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        return try url.withUnsafeFileSystemRepresentation { path in
            guard let path else { throw CocoaError(.fileReadInvalidFileName) }
            guard let resolved = realpath(path, nil) else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
            defer { free(resolved) }
            return String(cString: resolved)
        }
    }

    private static func isPermissionError(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains(error.code)
    }

    /// Finder may omit callbacks for protected folders registered alone.
    /// Observation ancestors do not expand menu scope or grant file access.
    public static func observationRoots(for folders: [URL], home: URL) -> Set<URL> {
        var roots = Set(folders.filter(\.isFileURL))
        let protectedFolders = ["Desktop", "Documents"].map {
            home.appendingPathComponent($0, isDirectory: true)
        }
        if home.isFileURL && folders.contains(where: { contains($0, in: protectedFolders) }) {
            roots.insert(home)
        }
        return roots
    }
}
