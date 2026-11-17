import AppKit

final class ShelfPanel: NSPanel {
    var onCancel: () -> Void = {}
    var onResignKey: () -> Void = {}
    var onKeyDown: (NSEvent) -> Bool = { _ in false }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none
        sharingType = .none
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func cancelOperation(_: Any?) {
        onCancel()
    }

    override func keyDown(with event: NSEvent) {
        if !onKeyDown(event) {
            super.keyDown(with: event)
        }
    }

    override func resignKey() {
        super.resignKey()
        onResignKey()
    }
}
