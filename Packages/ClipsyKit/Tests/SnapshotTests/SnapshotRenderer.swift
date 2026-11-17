import AppKit
import SwiftUI

let snapshotDirectory = ProcessInfo.processInfo.environment["CLIPSY_SNAPSHOTS"]
    .map { URL(filePath: $0, directoryHint: .isDirectory) }

/// renders a view in a borderless window that is never ordered in, so nothing appears on screen
@MainActor
enum SnapshotRenderer {
    enum Appearance: String, CaseIterable {
        case light
        case dark

        var name: NSAppearance.Name {
            self == .light ? .aqua : .darkAqua
        }
    }

    enum RenderError: Error {
        case noSnapshotDirectory
        case captureFailed
    }

    /// `size` nil uses the view's fitting size; `settle` lets `.task` loaders finish
    static func render(
        _ view: some View,
        named name: String,
        appearance: Appearance,
        size: CGSize? = nil,
        settle: Duration = .seconds(1)
    ) async throws {
        guard let directory = snapshotDirectory else { throw RenderError.noSnapshotDirectory }
        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size ?? .zero),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance.name)
        window.contentView = hostingView
        window.setContentSize(size ?? hostingView.fittingSize)
        hostingView.layoutSubtreeIfNeeded()
        try await Task.sleep(for: settle)
        if size == nil {
            window.setContentSize(hostingView.fittingSize)
        }
        hostingView.layoutSubtreeIfNeeded()

        let frame = hostingView.bounds
        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: frame) else { throw RenderError.captureFailed }
        hostingView.cacheDisplay(in: frame, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw RenderError.captureFailed }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appending(path: "\(name)-\(appearance.rawValue).png"))
    }
}
