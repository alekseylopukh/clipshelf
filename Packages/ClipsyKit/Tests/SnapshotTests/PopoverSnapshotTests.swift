import AppKit
import DesignSystem
import Media
import Pasting
import Store
import SwiftUI
import Testing
@testable import ShelfUI

/// renders the Sequence panel, popovers, edit sheets and filters offscreen; run with scripts/snapshots.sh
@MainActor
@Suite(.enabled(if: snapshotDirectory != nil), .serialized)
final class PopoverSnapshotTests {
    private let suiteName = "PopoverSnapshotTests-\(UUID().uuidString)"
    private let fixtures: SnapshotFixtures
    private let defaults: UserDefaults

    init() throws {
        fixtures = try SnapshotFixtures()
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("a unique suite name always opens a defaults domain")
        }
        self.defaults = defaults
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtures.directory)
    }

    @Test(arguments: SnapshotRenderer.Appearance.allCases)
    func `render the sequence panel`(appearance: SnapshotRenderer.Appearance) async throws {
        let cards = fixtures.cards
        for isEmpty in [true, false] {
            let sequence = PasteSequence(defaults: defaults)
            sequence.clear()
            if !isEmpty {
                sequence.add([1, 3, 6, 7])
            }
            let model = SequencePanelModel(
                sequence: sequence,
                loadCards: { ids in cards.filter { ids.contains($0.id) } },
                onPasteAll: { _ in }
            )
            let root = SequencePanelView(model: model)
                .background(GlassStandIn(cornerRadius: DesignTokens.sequencePanelCornerRadius))
                .padding(DesignTokens.sequencePanelScreenInset)
                .background(SnapshotWallpaper())
            try await SnapshotRenderer.render(
                root,
                named: isEmpty ? "sequence-empty" : "sequence",
                appearance: appearance
            )
        }
    }

    @Test(arguments: SnapshotRenderer.Appearance.allCases)
    func `render the rename popover`(appearance: SnapshotRenderer.Appearance) async throws {
        try await SnapshotRenderer.render(
            CardRenameField(title: "Launch Plan") { _ in }.background(.windowBackground),
            named: "rename",
            appearance: appearance
        )
    }

    @Test(arguments: SnapshotRenderer.Appearance.allCases, [1, 2, 3, 4, 6, 7, 8] as [Int64])
    func `render the preview popover`(appearance: SnapshotRenderer.Appearance, cardID: Int64) async throws {
        let card = try #require(fixtures.cards.first { $0.id == cardID })
        let representations = fixtures.representations
        let sizes = [("", PreviewSizeCalculator().defaultSize), ("-small", CGSize(width: 1438, height: 524))]
        for (suffix, available) in sizes {
            let root = CardPreviewView(card: card, available: available)
                .environment(\.richTextLoader, RichTextLoader(representations: representations))
                .environment(\.cardMediaLoader, CardMediaLoader(
                    representations: representations,
                    thumbnails: ThumbnailCache(directory: fixtures.thumbnails)
                ))
                .background(.windowBackground)
            try await SnapshotRenderer.render(
                root,
                named: "preview-\(cardID)\(suffix)",
                appearance: appearance,
                settle: .seconds(2)
            )
        }
    }

    @Test(arguments: SnapshotRenderer.Appearance.allCases)
    func `render the edit sheets`(appearance: SnapshotRenderer.Appearance) async throws {
        let text = "Quarterly plan\nShip the shelf by Friday."
        let textEditor = TextCardEditor(
            target: .card(2),
            representations: [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))]
        ) { _, _ in }
        try await SnapshotRenderer.render(
            TextCardEditorView(editor: textEditor, maxHeight: DesignTokens.shelfDefaultHeight * 2)
                .background(.windowBackground),
            named: "edit-text",
            appearance: appearance
        )

        let link = try #require(fixtures.cards.first { $0.kind == .link })
        try await SnapshotRenderer.render(
            LinkCardEditorView(
                editor: LinkCardEditor(card: link) { _ in } rename: { _ in },
                maxHeight: DesignTokens.shelfDefaultHeight * 2
            )
            .background(.windowBackground),
            named: "edit-link",
            appearance: appearance
        )

        let color = try #require(fixtures.cards.first { $0.kind == .color })
        try await SnapshotRenderer.render(
            ColorCardEditorView(
                editor: ColorCardEditor(card: color) { _ in },
                maxHeight: DesignTokens.shelfDefaultHeight * 2
            )
            .background(.windowBackground),
            named: "edit-color",
            appearance: appearance
        )

        let model = makeShelfModel()
        let boardEditor = BoardEditor(
            model: model,
            create: { _, _ in 0 },
            rename: { _, _ in },
            recolor: { _, _ in },
            move: { _, _ in },
            delete: { _ in },
            addCards: { _, _ in },
            moveCards: { _, _ in }
        )
        try await SnapshotRenderer.render(
            BoardEditorSheet(isNew: true)
                .environment(boardEditor)
                .background(.windowBackground),
            named: "edit-board",
            appearance: appearance
        )
    }

    @Test(arguments: SnapshotRenderer.Appearance.allCases)
    func `render the filter browser`(appearance: SnapshotRenderer.Appearance) async throws {
        let model = makeShelfModel()
        model.receiveApps(fixtures.cards.compactMap(\.sourceApp).reduce(into: []) { apps, app in
            if !apps.contains(where: { $0.bundleID == app.bundleID }) {
                apps.append(app)
            }
        })
        model.addToken(.kind(.link))
        try await SnapshotRenderer.render(
            FilterBrowser(model: model).background(.windowBackground),
            named: "filters",
            appearance: appearance
        )
    }

    private func makeShelfModel() -> ShelfModel {
        let model = ShelfModel(
            defaults: defaults,
            observe: { _ in AsyncThrowingStream { $0.finish() } },
            observeBoards: { AsyncThrowingStream { $0.finish() } }
        )
        model.receive(fixtures.cards)
        model.receiveBoards(fixtures.boards)
        return model
    }
}
