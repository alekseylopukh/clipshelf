import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onReopen: () -> Void = {}

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        onReopen()
        return false
    }
}
