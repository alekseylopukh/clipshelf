import AppKit
import DesignSystem
import Media
import SwiftUI
import Testing
@testable import ShelfUI

/// renders the shelf offscreen to .build/snapshots; run with scripts/snapshots.sh
@MainActor
@Suite(.enabled(if: snapshotDirectory != nil), .serialized)
final class ShelfSnapshotTests {
    enum Size: String, CaseIterable {
        case regular
        case compact

        var height: CGFloat {
            self == .regular ? DesignTokens.shelfDefaultHeight : DesignTokens.shelfMinimumHeight
        }
    }

    private static let width: CGFloat = 1920
    private let suiteName = "ShelfSnapshotTests-\(UUID().uuidString)"
    private let fixtures: SnapshotFixtures

    init() throws {
        fixtures = try SnapshotFixtures()
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtures.directory)
    }

    @Test(arguments: SnapshotRenderer.Appearance.allCases, Size.allCases)
    func `render the shelf`(appearance: SnapshotRenderer.Appearance, size: Size) async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let model = ShelfModel(
            defaults: defaults,
            observe: { _ in AsyncThrowingStream { $0.finish() } },
            observeBoards: { AsyncThrowingStream { $0.finish() } }
        )
        model.receive(fixtures.cards)
        model.receiveBoards(fixtures.boards)
        let presentation = ShelfPresentation()
        presentation.isVisible = true
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
        let commands = ShelfCommands()
        commands.newBoard = {}
        let representations = fixtures.representations
        let root = ShelfContainerView(
            presentation: presentation,
            model: model,
            commands: commands,
            onResize: {},
            onResizeEnded: {}
        )
        .environment(CardActions())
        .environment(boardEditor)
        .environment(\.richTextLoader, RichTextLoader(representations: representations))
        .environment(\.cardMediaLoader, CardMediaLoader(
            representations: representations,
            thumbnails: ThumbnailCache(directory: fixtures.thumbnails)
        ))
        .background(GlassStandIn())
        .padding(DesignTokens.shelfInset)
        .background(SnapshotWallpaper())

        model.select(fixtures.cards[1].id)
        try await SnapshotRenderer.render(
            root,
            named: "shelf-\(size.rawValue)",
            appearance: appearance,
            size: CGSize(width: Self.width, height: size.height + 2 * DesignTokens.shelfInset),
            settle: .seconds(2)
        )
    }
}

/// stands in for the desktop the glass shelf floats over
struct SnapshotWallpaper: View {
    var body: some View {
        LinearGradient(colors: [.teal, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// glass is composited by the window server and never reaches `cacheDisplay`, so this outlines the panel
struct GlassStandIn: View {
    var cornerRadius = DesignTokens.shelfCornerRadius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.regularMaterial)
            .strokeBorder(.white.opacity(0.5))
    }
}
