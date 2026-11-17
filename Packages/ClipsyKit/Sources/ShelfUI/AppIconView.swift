import AppKit
import DesignSystem
import SwiftUI
import Synchronization

struct AppIconView: View {
    let bundleID: String?
    let fallbackSymbol: String
    let size: CGFloat

    @State private var icon: CGImage?
    @State private var isMissing = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            if let icon {
                Image(decorative: icon, scale: displayScale)
                    .resizable()
            } else if bundleID == nil || isMissing {
                Image(systemName: fallbackSymbol)
                    .resizable()
                    .scaledToFit()
                    .padding(size * DesignTokens.appIconSymbolInsetRatio)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: AppIconRequest(bundleID: bundleID, pixelSize: size * displayScale)) {
            icon = nil
            isMissing = false
            guard let bundleID else { return }
            icon = await AppIconCache.shared.icon(
                for: bundleID,
                pixelSize: size * displayScale
            )
            isMissing = icon == nil
        }
    }
}

private struct AppIconRequest: Hashable {
    let bundleID: String?
    let pixelSize: CGFloat
}

final class AppIconCache: Sendable {
    static let shared = AppIconCache()

    private let icons = Mutex<[String: CGImage]>([:])

    @concurrent
    func icon(for bundleID: String, pixelSize: CGFloat) async -> CGImage? {
        let key = "\(bundleID)@\(Int(pixelSize))"
        if let cached = icons.withLock({ $0[key] }) {
            return cached
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        var rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        guard let image = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
            .cgImage(forProposedRect: &rect, context: nil, hints: nil)
        else { return nil }
        icons.withLock { $0[key] = image }
        return image
    }
}
