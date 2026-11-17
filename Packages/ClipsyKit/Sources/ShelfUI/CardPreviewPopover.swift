import AppKit
import DesignSystem
import Store
import SwiftUI

@MainActor
final class CardPreviewPopover: NSObject, NSPopoverDelegate {
    var returnKeyToShelf: () -> Void = {}
    var onResignKey: () -> Void = {}
    var onKeyDown: (NSEvent) -> Bool = { _ in false }
    var sharingType: () -> NSWindow.SharingType = { .none }

    private let popover = NSPopover()
    private let makeContent: () -> NSViewController
    private weak var anchor: NSView?
    private var isRequested = false
    private var keyMonitor: Any?
    private var resignKeyTask: Task<Void, Never>?

    init(model: ShelfModel, richTextLoader: RichTextLoader, mediaLoader: CardMediaLoader) {
        makeContent = {
            let controller = NSHostingController(rootView: CardPreviewRoot(model: model)
                .environment(\.richTextLoader, richTextLoader)
                .environment(\.cardMediaLoader, mediaLoader))
            controller.sizingOptions = .preferredContentSize
            return controller
        }
        super.init()
        popover.behavior = .applicationDefined
        popover.delegate = self
    }

    var isShown: Bool {
        popover.isShown
    }

    func toggle() {
        if isRequested {
            dismiss()
        } else if anchor != nil {
            isRequested = true
            show()
        }
    }

    /// shows on the next anchor, which the caller is about to move
    func request() {
        isRequested = true
    }

    func dismiss() {
        isRequested = false
        popover.close()
    }

    func attach(_ view: NSView) {
        anchor = view
        if isRequested {
            show()
        }
    }

    func detach(_ view: NSView) {
        guard anchor === view else { return }
        anchor = nil
        popover.close()
    }

    func popoverDidShow(_: Notification) {
        stopWatchingWindow()
        guard let window = popover.contentViewController?.view.window else { return }
        resignKeyTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: NSWindow.didResignKeyNotification,
                object: window
            ) {
                self?.onResignKey()
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            let isHandled = MainActor.assumeIsolated {
                event.window === window && self?.onKeyDown(event) == true
            }
            return isHandled ? nil : event
        }
    }

    func popoverWillClose(_: Notification) {
        stopWatchingWindow()
        if popover.contentViewController?.view.window?.isKeyWindow == true {
            returnKeyToShelf()
        }
    }

    func popoverDidClose(_: Notification) {
        if !popover.isShown {
            popover.contentViewController = nil
        }
    }

    private func stopWatchingWindow() {
        resignKeyTask?.cancel()
        resignKeyTask = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func show() {
        guard let anchor, anchor.window != nil else { return }
        if popover.contentViewController == nil {
            popover.contentViewController = makeContent()
        }
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
        popover.contentViewController?.view.window?.sharingType = sharingType()
        returnKeyToShelf()
    }
}

private struct CardPreviewRoot: View {
    let model: ShelfModel

    var body: some View {
        Group {
            if let card = model.cursorCard {
                CardPreviewView(card: card)
                    .id(card.id)
            }
        }
        .frame(width: DesignTokens.previewWidth, height: DesignTokens.previewHeight)
    }
}
