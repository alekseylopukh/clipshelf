import AppKit
import DesignSystem
import QuartzCore

@MainActor
final class PasteFlightPanel: NSPanel {
    private let flightLayer = CALayer()
    private let cardLayer = CALayer()
    private var source = CGRect.zero

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none
        sharingType = .none
        let view = NSView()
        view.wantsLayer = true
        contentView = view
        flightLayer.shadowOpacity = DesignTokens.pasteFlightShadowOpacity
        flightLayer.shadowRadius = DesignTokens.pasteFlightShadowRadius
        flightLayer.shadowOffset = .zero
        cardLayer.cornerRadius = DesignTokens.cardCornerRadius
        cardLayer.cornerCurve = .continuous
        cardLayer.masksToBounds = true
        cardLayer.contentsGravity = .resize
        flightLayer.addSublayer(cardLayer)
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    func lift(_ snapshot: PasteFlightSnapshot) {
        let frame = snapshot.frame
        source = frame
        setFrame(snapshot.screenFrame, display: false)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cardLayer.contents = snapshot.image
        cardLayer.contentsScale = snapshot.scale
        cardLayer.frame = CGRect(origin: .zero, size: frame.size)
        flightLayer.bounds = cardLayer.frame
        flightLayer.shadowPath = CGPath(
            roundedRect: cardLayer.frame,
            cornerWidth: DesignTokens.cardCornerRadius,
            cornerHeight: DesignTokens.cardCornerRadius,
            transform: nil
        )
        flightLayer.position = local(CGPoint(x: frame.midX, y: frame.midY))
        flightLayer.opacity = 1
        flightLayer.transform = CATransform3DIdentity
        contentView?.layer?.addSublayer(flightLayer)
        CATransaction.commit()
        orderFrontRegardless()
    }

    func land(at destination: CGRect?) async throws {
        defer {
            orderOut(nil)
            flightLayer.removeAllAnimations()
            cardLayer.contents = nil
        }
        if let destination, frame.contains(CGPoint(x: destination.midX, y: destination.midY)) {
            fly(to: CGPoint(x: destination.midX, y: destination.midY))
            try await Task.sleep(for: .seconds(DesignTokens.pasteFlightDuration))
        } else {
            fadeInPlace()
            try await Task.sleep(for: .seconds(DesignTokens.pasteFadeDuration))
        }
    }

    private func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
    }

    private func fly(to end: CGPoint) {
        let start = CGPoint(x: source.midX, y: source.midY)
        let arc = DesignTokens.pasteFlightArcFraction
        let control = CGPoint(x: start.x + (end.x - start.x) * (1 - arc), y: start.y + (end.y - start.y) * arc)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let path = CGMutablePath()
        path.move(to: local(start))
        path.addQuadCurve(to: local(end), control: local(control))

        let position = CAKeyframeAnimation(keyPath: "position")
        position.path = path
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1, 1, 0]
        opacity.keyTimes = [0, 0.6, 1]
        let group = CAAnimationGroup()
        group.animations = [position, scale, opacity]
        group.duration = DesignTokens.pasteFlightDuration
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        flightLayer.position = local(end)
        flightLayer.transform = CATransform3DMakeScale(
            DesignTokens.pasteFlightEndScale,
            DesignTokens.pasteFlightEndScale,
            1
        )
        flightLayer.opacity = 0
        flightLayer.add(group, forKey: "flight")
        CATransaction.commit()
    }

    private func fadeInPlace() {
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 1
        opacity.duration = DesignTokens.pasteFadeDuration
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flightLayer.opacity = 0
        flightLayer.add(opacity, forKey: "fade")
        CATransaction.commit()
    }
}
