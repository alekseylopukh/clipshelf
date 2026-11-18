import AppKit
import SwiftUI

@MainActor
public final class PopUpMenuAnchor {
    fileprivate weak var view: NSView?

    public init() {}

    public func popUp(_ menu: NSMenu) {
        guard let view else { return }
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: -DesignTokens.spacingSmall), in: view)
    }
}

private struct PopUpMenuAnchorView: NSViewRepresentable {
    final class AnchorView: NSView {
        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }
    }

    let anchor: PopUpMenuAnchor

    func makeNSView(context _: Context) -> AnchorView {
        let view = AnchorView()
        anchor.view = view
        return view
    }

    func updateNSView(_ view: AnchorView, context _: Context) {
        anchor.view = view
    }
}

public extension View {
    func popUpMenuAnchor(_ anchor: PopUpMenuAnchor) -> some View {
        background(PopUpMenuAnchorView(anchor: anchor))
    }
}
