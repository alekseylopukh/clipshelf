import AppKit
import os

extension ShelfController {
    private static let dragLogger = Logger(subsystem: "app.gonar.clipsy", category: "ShelfDrag")

    /// an AppKit drag, because a Transferable has a fixed list of types and a card has its own
    func beginDrag(_ drag: CardDrag) {
        guard !isDragging, let contentView = panel.contentView else { return }
        let cards = model.cards.filter { drag.cardIDs.contains($0.id) }
        guard !cards.isEmpty else { return }
        let start = contentView.convert(panel.mouseLocationOutsideOfEventStream, from: nil)
        let frame = NSRect(
            x: start.x - drag.pointer.x,
            y: start.y - drag.cardSize.height + drag.pointer.y,
            width: drag.cardSize.width,
            height: drag.cardSize.height
        ).intersection(contentView.bounds)
        guard !frame.isEmpty else { return }
        let image = snapshot(of: frame, in: contentView)
        isDragging = true
        Task {
            var didBegin = false
            defer { isDragging = didBegin }
            do {
                var contents: [CardDragContent] = []
                for card in cards {
                    try await contents.append(CardDragContent.make(
                        for: card,
                        representations: representations(card.id)
                    ))
                }
                guard isShown, NSEvent.pressedMouseButtons & 1 != 0, let event = currentDragEvent() else { return }
                let pointer = contentView.convert(panel.mouseLocationOutsideOfEventStream, from: nil)
                let draggingFrame = frame.offsetBy(dx: pointer.x - start.x, dy: pointer.y - start.y)
                let items = CardDragItems.writers(for: contents).map { writer in
                    let item = NSDraggingItem(pasteboardWriter: writer)
                    item.setDraggingFrame(draggingFrame, contents: image)
                    return item
                }
                contentView.beginDraggingSession(with: items, event: event, source: dragSource)
                didBegin = true
            } catch is CancellationError {
                return
            } catch {
                Self.dragLogger.error("drag failed: \(String(describing: type(of: error)), privacy: .public)")
                await presentError(error, title: String(
                    localized: "Clipsy can’t drag these cards.",
                    comment: "Title of the alert shown when the dragged cards cannot be read"
                ))
            }
        }
    }

    private func snapshot(of frame: NSRect, in view: NSView) -> NSImage {
        let image = NSImage(size: frame.size)
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: frame) else { return image }
        view.cacheDisplay(in: frame, to: bitmap)
        image.addRepresentation(bitmap)
        return image
    }

    private func currentDragEvent() -> NSEvent? {
        // the drag starts after the cards are read, so the event that crossed the drag threshold is gone by then
        NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: panel.mouseLocationOutsideOfEventStream,
            modifierFlags: NSEvent.modifierFlags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )
    }
}
