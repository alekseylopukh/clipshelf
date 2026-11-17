public enum SkipReason: Sendable, Equatable, CaseIterable {
    case paused
    case ownWrite
    case noFrontmostApp
    case ignoredApp
    case concealed
    case transient
}
