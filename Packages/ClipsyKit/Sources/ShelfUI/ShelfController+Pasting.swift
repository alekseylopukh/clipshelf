import AppKit
import os
import Pasting
import Store

extension ShelfController {
    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

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
                    self?.hideImmediately()
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
        let rect = PasteFlightSnapshot.contentRect(ofCardFrame: cardFrame, in: contentView.bounds)
        guard !rect.isEmpty, let bitmap = contentView.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
        contentView.cacheDisplay(in: rect, to: bitmap)
        guard let image = bitmap.cgImage else { return nil }
        return PasteFlightSnapshot(
            image: image,
            frame: panel.convertToScreen(contentView.convert(rect, to: nil)),
            screenFrame: screen.frame,
            scale: panel.backingScaleFactor
        )
    }

    func landingRect(isNeeded: Bool) async -> CGRect? {
        guard isNeeded, let pid = targetApplication?.processIdentifier,
              let primaryScreen = NSScreen.screens.first
        else { return nil }
        return await landingLocator.landingRect(in: pid, primaryScreenHeight: primaryScreen.frame.height)
    }
}
