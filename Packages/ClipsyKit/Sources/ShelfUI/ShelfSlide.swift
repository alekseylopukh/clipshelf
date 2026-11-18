import AppKit
import DesignSystem

/// slides the Shelf as one layer in the render server, independent of main-thread work
@MainActor
final class ShelfSlide {
    static let key = "shelfSlide"
    private static let keyPath = "transform.translation.y"

    private var view: NSView?
    private var panel: NSPanel?

    func attach(to view: NSView, in panel: NSPanel) {
        view.wantsLayer = true
        self.view = view
        self.panel = panel
    }

    func open(reduceMotion: Bool) {
        guard let panel else { return }
        if reduceMotion {
            view?.layer?.removeAnimation(forKey: Self.key)
            fade(panel, to: 1)
        } else {
            panel.alphaValue = 1
            slideIn(distance: panel.frame.height)
        }
    }

    func close(reduceMotion: Bool) -> TimeInterval {
        guard let panel else { return 0 }
        if reduceMotion {
            fade(panel, to: 0)
            return DesignTokens.shelfReducedFadeDuration
        }
        return slideOut(distance: panel.frame.height)
    }

    func reset() {
        view?.layer?.removeAnimation(forKey: Self.key)
        panel?.alphaValue = 1
    }

    func slideIn(distance: CGFloat) {
        guard let layer = view?.layer else { return }
        let spring = CASpringAnimation(perceptualDuration: DesignTokens.shelfOpenSlideDuration, bounce: 0)
        spring.keyPath = Self.keyPath
        spring.fromValue = currentOffset(of: layer) ?? -distance
        spring.toValue = 0
        spring.duration = spring.settlingDuration
        layer.add(spring, forKey: Self.key)
    }

    func slideOut(distance: CGFloat) -> TimeInterval {
        guard let layer = view?.layer else { return 0 }
        let animation = CABasicAnimation(keyPath: Self.keyPath)
        animation.fromValue = currentOffset(of: layer) ?? 0
        animation.toValue = -distance
        animation.duration = DesignTokens.shelfCloseSlideDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: Self.key)
        return animation.duration
    }

    private func fade(_ panel: NSPanel, to alpha: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignTokens.shelfReducedFadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = alpha
        }
    }

    private func currentOffset(of layer: CALayer) -> CGFloat? {
        guard layer.animation(forKey: Self.key) != nil else { return nil }
        return layer.presentation()?.value(forKeyPath: Self.keyPath) as? CGFloat
    }
}
