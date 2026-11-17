import AppKit
import Carbon.HIToolbox
import DesignSystem
import os
import Pasting
import SwiftUI

@MainActor
public final class ShelfController {
    public private(set) var targetApplication: NSRunningApplication?

    private static let heightKey = "ShelfHeight"
    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    private let panel = ShelfPanel()
    private let presentation = ShelfPresentation()
    private let calculator = ShelfFrameCalculator()
    private let model: ShelfModel
    private let paster: PasteCoordinator
    private let defaults: UserDefaults
    private var resizeStart: (mouseY: CGFloat, height: CGFloat)?

    public init(model: ShelfModel, paster: PasteCoordinator, defaults: UserDefaults = .standard) {
        self.model = model
        self.paster = paster
        self.defaults = defaults
        let hostingView = NSHostingView(rootView: ShelfContainerView(
            presentation: presentation,
            model: model,
            onResize: { [weak self] in self?.resize() },
            onResizeEnded: { [weak self] in self?.endResize() }
        ))
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        let contentView = NSView()
        contentView.addSubview(hostingView)
        panel.contentView = contentView
        panel.onCancel = { [weak self] in self?.hide() }
        panel.onResignKey = { [weak self] in self?.closeOnFocusLoss() }
        panel.onKeyDown = { [weak self] event in self?.handleKeyDown(event) ?? false }
    }

    public var isShown: Bool {
        presentation.isVisible
    }

    public func toggle() {
        if isShown {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard !isShown else { return }
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.screens.first
        else {
            return
        }
        let frontmost = NSWorkspace.shared.frontmostApplication
        targetApplication = frontmost == NSRunningApplication.current ? nil : frontmost
        panel.setFrame(calculator.frame(height: storedHeight, in: screen.visibleFrame), display: false)
        model.didOpen()
        panel.makeKeyAndOrderFront(nil)
        withAnimation(reduceMotion ? .default : .spring) {
            presentation.isVisible = true
        }
    }

    public func hide() {
        guard isShown else { return }
        resizeStart = nil
        withAnimation(reduceMotion ? .default : .snappy) {
            presentation.isVisible = false
        } completion: { [weak self] in
            guard let self, !isShown else { return }
            panel.orderOut(nil)
        }
    }

    func perform(_ action: PasteCoordinator.Action, cardID: Int64, plainModifier: Bool) async {
        do {
            try await paster.perform(
                action,
                cardID: cardID,
                plainModifier: plainModifier,
                target: targetApplication,
                hideShelf: { [weak self] in self?.hideImmediately() }
            )
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("paste failed: \(String(describing: type(of: error)), privacy: .public)")
            hideImmediately()
            let alert = NSAlert(error: error)
            alert.messageText = String(
                localized: "Clipsy can’t paste this card.",
                comment: "Title of the alert shown when a card's contents cannot be read for pasting"
            )
            alert.informativeText = error.localizedDescription
            NSApplication.shared.activate()
            alert.runModal()
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])
        let action: PasteCoordinator.Action
        if [kVK_Return, kVK_ANSI_KeypadEnter].contains(Int(event.keyCode)), modifiers.isSubset(of: .shift) {
            action = .paste
        } else if event.charactersIgnoringModifiers?.lowercased() == "c", modifiers.subtracting(.shift) == .command {
            action = .copy
        } else {
            return false
        }
        guard !event.isARepeat, model.selection.count == 1, let cardID = model.selection.first else { return true }
        Task {
            await perform(action, cardID: cardID, plainModifier: modifiers.contains(.shift))
        }
        return true
    }

    /// orders the panel out at once, because a keystroke posted while it is key would land in the shelf
    private func hideImmediately() {
        resizeStart = nil
        presentation.isVisible = false
        panel.orderOut(nil)
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var storedHeight: CGFloat {
        defaults.object(forKey: Self.heightKey) == nil
            ? DesignTokens.shelfDefaultHeight
            : defaults.double(forKey: Self.heightKey)
    }

    private func closeOnFocusLoss() {
        guard panel.attachedSheet == nil, panel.childWindows?.isEmpty ?? true else { return }
        hide()
    }

    private func resize() {
        guard let screen = panel.screen else { return }
        let mouseY = NSEvent.mouseLocation.y
        let start = resizeStart ?? (mouseY, panel.frame.height)
        resizeStart = start
        let height = start.height + mouseY - start.mouseY
        panel.setFrame(calculator.frame(height: height, in: screen.visibleFrame), display: true)
    }

    private func endResize() {
        guard resizeStart != nil else { return }
        resizeStart = nil
        defaults.set(Double(panel.frame.height), forKey: Self.heightKey)
    }
}
