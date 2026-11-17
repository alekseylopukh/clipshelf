import AppKit
import SwiftUI

struct CardPreviewAnchor: NSViewRepresentable {
    final class AnchorView: NSView {
        var onAttach: (NSView) -> Void = { _ in }
        var onDetach: (NSView) -> Void = { _ in }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                onDetach(self)
            } else {
                onAttach(self)
            }
        }

        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }
    }

    @Environment(CardActions.self) private var actions

    func makeNSView(context _: Context) -> AnchorView {
        let view = AnchorView()
        let actions = actions
        view.onAttach = { actions.attachPreviewAnchor($0) }
        view.onDetach = { actions.detachPreviewAnchor($0) }
        return view
    }

    func updateNSView(_: AnchorView, context _: Context) {}
}
