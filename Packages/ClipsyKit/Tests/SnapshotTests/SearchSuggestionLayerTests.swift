import AppKit
import DesignSystem
import Store
import SwiftUI
import Testing
@testable import ShelfUI

/// the suggestion list hangs below the top bar and must draw over the cards, not behind them
@MainActor
@Suite(.serialized)
final class SearchSuggestionLayerTests {
    private let suiteName = "SearchSuggestionLayerTests-\(UUID().uuidString)"
    private let fixtures: SnapshotFixtures

    init() throws {
        fixtures = try SnapshotFixtures()
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: fixtures.directory)
    }

    @Test(arguments: SnapshotRenderer.Appearance.allCases)
    func `suggestions draw over the cards`(appearance: SnapshotRenderer.Appearance) async throws {
        let withList = try await render(showingSuggestions: true, appearance: appearance)
        let withoutList = try await render(showingSuggestions: false, appearance: appearance)
        #expect(withList.pixelsWide == withoutList.pixelsWide)
        #expect(withList.pixelsHigh == withoutList.pixelsHigh)

        let scale = CGFloat(withList.pixelsWide) / Self.size.width
        let firstCard = CGRect(
            x: DesignTokens.shelfPadding,
            y: DesignTokens.shelfPadding * 2 + DesignTokens.topBarControlHeight,
            width: DesignTokens.cardSide,
            height: DesignTokens.cardSide - DesignTokens.shelfPadding * 2
        )
        let columns = Int(firstCard.minX * scale) ..< Int(firstCard.maxX * scale)
        var changed = 0
        for y in Int(firstCard.minY * scale) ..< Int(firstCard.maxY * scale) {
            for x in columns where differs(withList, withoutList, x: x, y: y) {
                changed += 1
            }
        }
        #expect(changed > 500)
    }

    private static let size = CGSize(width: 600, height: DesignTokens.shelfDefaultHeight)

    private func render(
        showingSuggestions: Bool,
        appearance: SnapshotRenderer.Appearance
    ) async throws -> NSBitmapImageRep {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let model = ShelfModel(
            defaults: defaults,
            observe: { _ in AsyncThrowingStream { $0.finish() } },
            observeBoards: { AsyncThrowingStream { $0.finish() } }
        )
        model.receive(fixtures.cards.filter { $0.kind == .text })
        model.query = "la"
        model.isSearchFieldFocused = showingSuggestions
        #expect(model.suggestions.isEmpty == false)
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
        let root = ShelfContainerView(
            presentation: presentation,
            model: model,
            commands: ShelfCommands(),
            onResize: {},
            onResizeEnded: {}
        )
        .environment(CardActions())
        .environment(boardEditor)
        return try await SnapshotRenderer.bitmap(root, appearance: appearance, size: Self.size)
    }

    private func differs(_ lhs: NSBitmapImageRep, _ rhs: NSBitmapImageRep, x: Int, y: Int) -> Bool {
        guard let left = lhs.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
              let right = rhs.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)
        else { return false }
        return abs(left.redComponent - right.redComponent)
            + abs(left.greenComponent - right.greenComponent)
            + abs(left.blueComponent - right.blueComponent) > 0.15
    }
}
