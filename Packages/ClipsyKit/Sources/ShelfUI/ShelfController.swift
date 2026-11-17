import AppKit
import DesignSystem
import SwiftUI

@MainActor
public final class ShelfController {
    public private(set) var targetApplication: NSRunningApplication?

    private static let heightKey = "ShelfHeight"

    private let panel = ShelfPanel()
    private let presentation = ShelfPresentation()
    private let calculator = ShelfFrameCalculator()
    private let defaults: UserDefaults
    private var resizeStart: (mouseY: CGFloat, height: CGFloat)?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let hostingView = NSHostingView(rootView: ShelfContainerView(
            presentation: presentation,
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
