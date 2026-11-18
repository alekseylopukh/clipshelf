import AppKit
import DesignSystem
import os
import Pasting
import Store

extension ShelfController {
    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")
    private static let signposter = OSSignposter(subsystem: "app.gonar.clipsy", category: "Shelf")

    func perform(_ action: PasteCoordinator.Action, cards: [CardSummary], plainModifier: Bool) async {
        let snapshot = flightSnapshot(for: action, cards: cards)
        async let landing = landingRect(isNeeded: snapshot != nil)
        do {
            try await paster.perform(
                action,
                cards: cards,
                plainModifier: plainModifier,
                target: targetApplication,
                hideShelf: { [weak self] in
                    if action == .copy {
                        self?.hide()
                    } else {
                        self?.hideImmediately()
                    }
                    if let snapshot {
                        self?.flight.lift(snapshot)
                    }
                }
            )
            if snapshot != nil {
                try await flight.land(at: landing)
            }
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

    func flightSnapshot(for action: PasteCoordinator.Action, cards: [CardSummary]) -> PasteFlightSnapshot? {
        guard !reduceMotion, isShown, cards.count == 1, targetApplication != nil,
              paster.pastesIntoTarget(action),
              let cardFrame = actions.cardFrames[cards[0].id], let screen = panel.screen,
              let contentView = panel.contentView
        else { return nil }
        let state = Self.signposter.beginInterval("pasteSnapshot")
        defer { Self.signposter.endInterval("pasteSnapshot", state) }
        let bounds = contentView.bounds
        let cardRect = PasteFlightSnapshot.contentRect(ofCardFrame: cardFrame, in: bounds)
        let showsAfterimage = DesignTokens.pasteAfterimageIsEnabled
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let captureRect = showsAfterimage
            ? PasteFlightSnapshot.stripRect(ofCardFrames: Array(actions.cardFrames.values), in: bounds)
            : cardRect
        guard !cardRect.isEmpty, !captureRect.isEmpty,
              let bitmap = contentView.bitmapImageRepForCachingDisplay(in: captureRect)
        else { return nil }
        contentView.cacheDisplay(in: captureRect, to: bitmap)
        let crop = PasteFlightSnapshot.cropRect(of: cardRect, in: captureRect, scale: panel.backingScaleFactor)
        guard let captured = bitmap.cgImage,
              let image = showsAfterimage ? captured.cropping(to: crop) : captured
        else { return nil }
        return PasteFlightSnapshot(
            image: image,
            frame: screenRect(of: cardRect, in: contentView),
            screenFrame: screen.frame,
            scale: panel.backingScaleFactor,
            afterimage: showsAfterimage ? captured : nil,
            afterimageFrame: screenRect(of: captureRect, in: contentView),
            cardFrameInAfterimage: cardRect.offsetBy(dx: -captureRect.minX, dy: -captureRect.minY),
            glassFrame: panel.frame.insetBy(dx: DesignTokens.shelfShadowMargin, dy: DesignTokens.shelfShadowMargin)
        )
    }

    private func screenRect(of rect: CGRect, in contentView: NSView) -> CGRect {
        panel.convertToScreen(contentView.convert(rect, to: nil))
    }

    func landingRect(isNeeded: Bool) async -> CGRect? {
        guard isNeeded, let pid = targetApplication?.processIdentifier,
              let primaryScreen = NSScreen.screens.first
        else { return nil }
        return await landingLocator.landingRect(in: pid, primaryScreenHeight: primaryScreen.frame.height)
    }
}
