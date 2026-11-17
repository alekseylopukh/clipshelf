import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onReopen: () -> Void = {}
    var onOpenURLs: ([URL]) -> Void = { _ in }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        onReopen()
        return false
    }

    func application(_: NSApplication, open urls: [URL]) {
        onOpenURLs(urls)
    }
}
