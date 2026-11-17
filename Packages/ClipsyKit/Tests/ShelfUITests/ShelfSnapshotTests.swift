import AppKit
import DesignSystem
import Media
import SwiftUI
import Testing
@testable import ShelfUI

private let snapshotDirectory = ProcessInfo.processInfo.environment["CLIPSY_SNAPSHOTS"]
    .map { URL(filePath: $0, directoryHint: .isDirectory) }

/// renders the shelf offscreen to .build/snapshots; run with scripts/snapshots.sh
@MainActor
@Suite(.enabled(if: snapshotDirectory != nil), .serialized)
final class ShelfSnapshotTests {
    enum Appearance: String, CaseIterable {
        case light
        case dark

        var name: NSAppearance.Name {
            self == .light ? .aqua : .darkAqua
        }
    }

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

    @Test(arguments: Appearance.allCases, Size.allCases)
    func `render the shelf`(appearance: Appearance, size: Size) async throws {
        let directory = try #require(snapshotDirectory)
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

        let frame = CGRect(x: 0, y: 0, width: Self.width, height: size.height + 2 * DesignTokens.shelfInset)
        let hostingView = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance.name)
        window.contentView = hostingView
        model.select(fixtures.cards[1].id)
        hostingView.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .seconds(2))
        hostingView.layoutSubtreeIfNeeded()

        let rep = try #require(hostingView.bitmapImageRepForCachingDisplay(in: frame))
        hostingView.cacheDisplay(in: frame, to: rep)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appending(path: "shelf-\(size.rawValue)-\(appearance.rawValue).png"))
    }
}

/// stands in for the desktop the glass shelf floats over
private struct SnapshotWallpaper: View {
    var body: some View {
        LinearGradient(colors: [.teal, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// glass is composited by the window server and never reaches `cacheDisplay`, so this outlines the panel
private struct GlassStandIn: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.shelfCornerRadius)
            .fill(.regularMaterial)
            .strokeBorder(.white.opacity(0.5))
    }
}
