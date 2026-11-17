import AppKit

final class SequencePanel: NSPanel, NSDraggingDestination {
    /// card references from the shelf are taken by the SwiftUI drop destination, so they never reach the panel
    private static let droppedTypes: [NSPasteboard.PasteboardType] = [
        .string, .rtf, .rtfd, .html, .URL, .fileURL, .png, .tiff, .pdf
    ]

    var onCancel: () -> Void = {}
    var onDrop: (NSPasteboard) -> Void = { _ in }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        isMovable = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        sharingType = .none
        registerForDraggedTypes(Self.droppedTypes)
    }

    func draggingEntered(_: any NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        onDrop(sender.draggingPasteboard)
        return true
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
}
