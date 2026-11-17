import AppKit

final class CardDragSource: NSObject, NSDraggingSource {
    var onEnd: () -> Void = {}

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor _: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        onEnd()
    }
}
