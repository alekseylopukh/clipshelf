import AppKit
import DesignSystem
import QuartzCore

@MainActor
final class PasteFlightPanel: NSPanel {
    private let ghost = NSGlassEffectView()
    private let layerView = NSView()
    private let afterimageLayer = CALayer()
    private let afterimageMask = CAShapeLayer()
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
        ghost.cornerRadius = DesignTokens.shelfCornerRadius
        ghost.style = .regular
        ghost.isHidden = true
        view.addSubview(ghost)
        // a layer-hosting view keeps the afterimage and the card above the ghost
        layerView.layer = CALayer()
        layerView.wantsLayer = true
        view.addSubview(layerView)
        contentView = view
        afterimageMask.fillRule = .evenOdd
        afterimageLayer.mask = afterimageMask
        afterimageLayer.contentsGravity = .resize
        afterimageLayer.isHidden = true
        flightLayer.shadowOffset = .zero
        cardLayer.cornerRadius = DesignTokens.cardCornerRadius
        cardLayer.cornerCurve = .continuous
        cardLayer.masksToBounds = true
        cardLayer.contentsGravity = .resize
        flightLayer.addSublayer(cardLayer)
        layerView.layer?.addSublayer(afterimageLayer)
        layerView.layer?.addSublayer(flightLayer)
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
        layerView.frame = contentView?.bounds ?? .zero
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
        flightLayer.shadowRadius = DesignTokens.pasteFlightShadowRadius
        flightLayer.shadowOpacity = DesignTokens.pasteFlightShadowOpacity
        flightLayer.position = local(CGPoint(x: frame.midX, y: frame.midY))
        flightLayer.opacity = 1
        flightLayer.transform = CATransform3DIdentity
        let showsAfterimage = showAfterimage(of: snapshot)
        CATransaction.commit()
        orderFrontRegardless()
        if showsAfterimage {
            fadeAfterimage()
        }
    }

    func land(at destination: CGRect?) async throws {
        defer {
            orderOut(nil)
            flightLayer.removeAllAnimations()
            afterimageLayer.removeAllAnimations()
            cardLayer.contents = nil
            afterimageLayer.contents = nil
            afterimageLayer.isHidden = true
            ghost.isHidden = true
        }
        let duration = if let destination, frame.contains(CGPoint(x: destination.midX, y: destination.midY)) {
            fly(to: CGPoint(x: destination.midX, y: destination.midY))
        } else {
            fadeInPlace()
        }
        try await Task.sleep(for: .seconds(duration))
    }

    private func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
    }

    private func local(_ rect: CGRect) -> CGRect {
        CGRect(origin: local(rect.origin), size: rect.size)
    }

    private func showAfterimage(of snapshot: PasteFlightSnapshot) -> Bool {
        guard let afterimage = snapshot.afterimage else {
            ghost.isHidden = true
            afterimageLayer.isHidden = true
            return false
        }
        ghost.frame = local(snapshot.glassFrame)
        ghost.alphaValue = 1
        ghost.isHidden = false
        afterimageLayer.contents = afterimage
        afterimageLayer.contentsScale = snapshot.scale
        afterimageLayer.frame = local(snapshot.afterimageFrame)
        afterimageLayer.opacity = 1
        afterimageLayer.isHidden = false
        let path = CGMutablePath()
        path.addRect(afterimageLayer.bounds)
        path.addRoundedRect(
            in: snapshot.cardFrameInAfterimage,
            cornerWidth: DesignTokens.cardCornerRadius,
            cornerHeight: DesignTokens.cardCornerRadius
        )
        afterimageMask.frame = afterimageLayer.bounds
        afterimageMask.contentsScale = snapshot.scale
        afterimageMask.path = path
        return true
    }

    private func fadeAfterimage() {
        let duration = DesignTokens.pasteAfterimageDuration
        let drop = DesignTokens.pasteAfterimageDrop
        let timing = CAMediaTimingFunction(name: .easeOut)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timing
            ghost.animator().alphaValue = 0
            ghost.animator().setFrameOrigin(CGPoint(x: ghost.frame.minX, y: ghost.frame.minY - drop))
        }
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 1
        let position = CABasicAnimation(keyPath: "position.y")
        position.fromValue = afterimageLayer.position.y
        let group = CAAnimationGroup()
        group.animations = [opacity, position]
        group.duration = duration
        group.timingFunction = timing
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        afterimageLayer.opacity = 0
        afterimageLayer.position.y -= drop
        afterimageLayer.add(group, forKey: "afterimage")
        CATransaction.commit()
    }

    private func fly(to end: CGPoint) -> TimeInterval {
        let start = CGPoint(x: source.midX, y: source.midY)
        let duration = PasteFlightSnapshot.flightDuration(distance: hypot(end.x - start.x, end.y - start.y))
        let arc = DesignTokens.pasteFlightArcFraction
        let control = CGPoint(x: start.x + (end.x - start.x) * (1 - arc), y: start.y + (end.y - start.y) * arc)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let path = CGMutablePath()
        path.move(to: local(start))
        path.addQuadCurve(to: local(end), control: local(control))

        let position = CAKeyframeAnimation(keyPath: "position")
        position.path = path
        position.duration = duration
        position.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0, 0.15, 1)
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1, DesignTokens.pasteLiftScale, DesignTokens.pasteFlightLandingScale]
        scale.keyTimes = [0, NSNumber(value: DesignTokens.pasteLiftDuration / duration), 1]
        scale.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(controlPoints: 0.5, 0, 0.9, 0.5)
        ]
        scale.duration = duration
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1, 1, 0]
        opacity.keyTimes = [0, NSNumber(value: DesignTokens.pasteFlightFadeStart), 1]
        opacity.duration = duration
        let shadowRadius = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadius.fromValue = DesignTokens.pasteFlightShadowRadius
        shadowRadius.toValue = DesignTokens.pasteFlightLiftedShadowRadius
        let shadowOpacity = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacity.fromValue = DesignTokens.pasteFlightShadowOpacity
        shadowOpacity.toValue = DesignTokens.pasteFlightLiftedShadowOpacity
        for shadow in [shadowRadius, shadowOpacity] {
            shadow.duration = DesignTokens.pasteLiftDuration
            shadow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        }
        let group = CAAnimationGroup()
        group.animations = [position, scale, opacity, shadowRadius, shadowOpacity]
        group.duration = duration

        flightLayer.position = local(end)
        flightLayer.transform = CATransform3DMakeScale(
            DesignTokens.pasteFlightLandingScale,
            DesignTokens.pasteFlightLandingScale,
            1
        )
        flightLayer.opacity = 0
        flightLayer.shadowRadius = DesignTokens.pasteFlightLiftedShadowRadius
        flightLayer.shadowOpacity = DesignTokens.pasteFlightLiftedShadowOpacity
        flightLayer.add(group, forKey: "flight")
        CATransaction.commit()
        return duration
    }

    private func fadeInPlace() -> TimeInterval {
        let opacity = CASpringAnimation(perceptualDuration: DesignTokens.pasteFadeSpringDuration, bounce: 0)
        opacity.keyPath = "opacity"
        opacity.fromValue = 1
        opacity.toValue = 0
        let scale = CASpringAnimation(perceptualDuration: DesignTokens.pasteFadeSpringDuration, bounce: 0)
        scale.keyPath = "transform.scale"
        scale.fromValue = 1
        scale.toValue = DesignTokens.pasteFadeEndScale
        let duration = opacity.settlingDuration
        opacity.duration = duration
        scale.duration = duration
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flightLayer.opacity = 0
        flightLayer.transform = CATransform3DMakeScale(
            DesignTokens.pasteFadeEndScale,
            DesignTokens.pasteFadeEndScale,
            1
        )
        flightLayer.add(opacity, forKey: "fade")
        flightLayer.add(scale, forKey: "fadeScale")
        CATransaction.commit()
        return duration
    }
}
