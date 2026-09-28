public enum ApplicationTerminationPolicy {
    /// An ordinary user quit may discard an idle draft, but never a running write.
    public static func canQuit(pendingCreations: Int, hasActiveWrite: Bool,
                               hasFileOperation: Bool, hasFavoriteOperation: Bool) -> Bool {
        pendingCreations == 0 && !hasActiveWrite && !hasFileOperation && !hasFavoriteOperation
    }
}
