import AppKit
import os
import Store
import SwiftUI

extension ShelfController {
    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "ShelfFiles")

    func openOrReveal(_ command: CardCommand, on ids: [Int64]) {
        guard ids.count == 1, let cardID = ids.first else { return }
        Task {
            if command == .showInFinder {
                await showInFinder(cardID)
            } else {
                await open(cardID)
            }
        }
    }

    func requestPopUp(for command: CardCommand, on ids: [Int64]) {
        let kind: CardPopUp.Kind = switch command {
        case .openWith: .openWith
        case .share: .share
        default: .addToBoard
        }
        guard let anchorID = model.cursorID.flatMap({ ids.contains($0) ? $0 : nil }) ?? ids.first else { return }
        actions.popUp = CardPopUp(kind: kind, anchorID: anchorID, cardIDs: ids)
    }

    private func open(_ cardID: Int64) async {
        guard let card = model.cards.first(where: { $0.id == cardID }), card.kind == .link || card.kind == .file else {
            return
        }
        do {
            let loaded = card.kind == .file ? try await representations(cardID) : []
            for url in card.openableURLs(in: loaded) {
                try await NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration())
            }
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("open failed: \(String(describing: type(of: error)), privacy: .public)")
            await presentError(error, title: String(
                localized: "Clipsy can’t open this card.",
                comment: "Title of the alert shown when a card's link or file cannot be opened"
            ))
        }
    }

    func showPopUp(_ popUp: CardPopUp, at frame: CGRect) {
        guard let contentView = panel.contentView else { return }
        let cards = model.cards.filter { popUp.cardIDs.contains($0.id) }
        let menu: NSMenu
        switch popUp.kind {
        case .addToBoard:
            menu = NSHostingMenu(rootView: AddToBoardItems(cards: cards).environment(boardEditor))
        case .openWith:
            guard cards.count == 1, let card = cards.first else { return }
            Task {
                let applications = await OpenWithApplication.applications(for: card)
                guard isShown, !applications.isEmpty, let contentView = panel.contentView else { return }
                NSHostingMenu(rootView: OpenWithItems(cardID: card.id, applications: applications)
                    .environment(actions))
                    .popUp(positioning: nil, at: Self.menuPoint(for: frame, in: contentView), in: contentView)
            }
            return
        case .share:
            Task {
                await share(cards, at: frame)
            }
            return
        }
        let point = Self.menuPoint(for: frame, in: contentView)
        Task {
            menu.popUp(positioning: nil, at: point, in: contentView)
        }
    }

    private static func menuPoint(for frame: CGRect, in contentView: NSView) -> NSPoint {
        NSPoint(x: frame.midX, y: contentView.bounds.height - frame.midY)
    }

    func open(_ cardID: Int64, with application: URL) async {
        guard let card = model.cards.first(where: { $0.id == cardID }), card.kind == .file else { return }
        do {
            let urls = try await card.openableURLs(in: representations(cardID))
            _ = try await NSWorkspace.shared.open(
                urls,
                withApplicationAt: application,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("open with failed: \(String(describing: type(of: error)), privacy: .public)")
            await presentError(error, title: String(
                localized: "Clipsy can’t open this card.",
                comment: "Title of the alert shown when a card's link or file cannot be opened"
            ))
        }
    }

    func showInFinder(_ cardID: Int64) async {
        guard let card = model.cards.first(where: { $0.id == cardID }), card.kind == .file else { return }
        do {
            let urls = try await Self.existingFiles(card.openableURLs(in: representations(cardID)))
            guard !urls.isEmpty else { throw CocoaError(.fileNoSuchFile) }
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("show in finder failed: \(String(describing: type(of: error)), privacy: .public)")
            await presentError(error, title: String(
                localized: "Clipsy can’t show this file in Finder.",
                comment: "Title of the alert shown when a file card's files cannot be shown in Finder"
            ))
        }
    }

    private func share(_ cards: [CardSummary], at frame: CGRect) async {
        do {
            var loaded: [(card: CardSummary, representations: [Representation])] = []
            for card in cards {
                try await loaded.append((card, representations(card.id)))
            }
            let items = CardShareItems.items(for: loaded)
            guard isShown, !items.isEmpty, let contentView = panel.contentView else { return }
            let rect = NSRect(
                x: frame.minX,
                y: contentView.bounds.height - frame.maxY,
                width: frame.width,
                height: frame.height
            )
            NSSharingServicePicker(items: items).show(relativeTo: rect, of: contentView, preferredEdge: .maxY)
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("share failed: \(String(describing: type(of: error)), privacy: .public)")
            await presentError(error, title: String(
                localized: "Clipsy can’t share these cards.",
                comment: "Title of the alert shown when the selected cards cannot be read for sharing"
            ))
        }
    }

    @concurrent
    private static func existingFiles(_ urls: [URL]) async -> [URL] {
        urls.filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
    }
}
