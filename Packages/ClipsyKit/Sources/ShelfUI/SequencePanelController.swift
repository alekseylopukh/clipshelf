import AppKit
import DesignSystem
import Observation
import os
import SwiftUI

@MainActor
public final class SequencePanelController {
    public typealias DropRecording = @MainActor (NSPasteboard) async throws -> Void

    private static let frameName = "SequencePanel"
    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Sequence")

    private let panel = SequencePanel()
    private let model: SequencePanelModel
    private let recordDrop: DropRecording
    private var hasPosition: Bool

    /// `recordDrop` captures content dropped from other apps; the capture then joins the open Sequence
    public init(model: SequencePanelModel, recordDrop: @escaping DropRecording) {
        self.model = model
        self.recordDrop = recordDrop
        let hostingView = NSHostingView(rootView: SequencePanelView(model: model))
        hostingView.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hostingView
        panel.onCancel = { model.sequence.close() }
        hasPosition = panel.setFrameUsingName(Self.frameName)
        panel.setFrameAutosaveName(Self.frameName)
        panel.onDrop = { [weak self] pasteboard in self?.drop(pasteboard) }
    }

    public var isShownInScreenCapture: Bool {
        get { panel.sharingType != .none }
        set { panel.sharingType = newValue ? .readOnly : .none }
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

    private func drop(_ pasteboard: NSPasteboard) {
        // immediate, so the drag pasteboard is read before the drop returns
        Task.immediate {
            do {
                try await recordDrop(pasteboard)
            } catch {
                Self.logger.error("recording a drop failed: \(String(describing: type(of: error)), privacy: .public)")
                let alert = NSAlert(error: error)
                alert.messageText = String(
                    localized: "Clipsy can’t add the dropped content.",
                    comment: "Title of the alert shown when content dropped on the Sequence panel cannot be saved"
                )
                alert.informativeText = error.localizedDescription
                NSApplication.shared.activate()
                alert.runModal()
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
