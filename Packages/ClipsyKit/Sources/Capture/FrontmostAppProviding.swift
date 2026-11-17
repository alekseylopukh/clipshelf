import AppKit
import Store

@MainActor
public protocol FrontmostAppProviding {
    /// nil when there is no frontmost app or it has no bundle id (WD-23)
    var frontmostApp: SourceApp? { get }
}

extension NSWorkspace: FrontmostAppProviding {
    public var frontmostApp: SourceApp? {
        guard let app = frontmostApplication, let bundleID = app.bundleIdentifier else { return nil }
        return SourceApp(bundleID: bundleID, name: app.localizedName ?? bundleID)
    }
}
