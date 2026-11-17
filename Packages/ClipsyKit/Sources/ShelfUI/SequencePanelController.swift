import AppKit
import DesignSystem
import Observation
import SwiftUI

@MainActor
public final class SequencePanelController {
    private static let frameName = "SequencePanel"

    private let panel = SequencePanel()
    private let model: SequencePanelModel
    private var hasPosition: Bool

    public init(model: SequencePanelModel) {
        self.model = model
        let hostingView = NSHostingView(rootView: SequencePanelView(model: model))
        hostingView.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hostingView
        panel.onCancel = { model.sequence.close() }
        hasPosition = panel.setFrameUsingName(Self.frameName)
        panel.setFrameAutosaveName(Self.frameName)
    }

    /// shows the panel while the Sequence is open and hides it when it closes, until the calling task is cancelled
    public func run() async {
        let sequence = model.sequence
        for await isOpen in Observations({ sequence.isOpen }) {
            if isOpen {
                show()
            } else {
                await hide()
            }
        }
    }

    private func show() {
        if !hasPosition {
            placeAtDefaultPosition()
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    private func hide() async {
        guard panel.isVisible else { return }
        await NSAnimationContext.runAnimationGroup { _ in
            panel.animator().alphaValue = 0
        }
        if model.sequence.isOpen {
            panel.alphaValue = 1
        } else {
            panel.orderOut(nil)
        }
    }

    private func placeAtDefaultPosition() {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.screens.first
        else {
            return
        }
        let visible = screen.visibleFrame
        let inset = DesignTokens.sequencePanelScreenInset
        panel.setFrameTopLeftPoint(
            NSPoint(x: visible.maxX - DesignTokens.sequencePanelWidth - inset, y: visible.maxY - inset)
        )
        hasPosition = true
    }
}
