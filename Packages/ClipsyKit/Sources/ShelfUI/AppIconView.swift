import AppKit
import DesignSystem
import SwiftUI
import Synchronization

struct AppIconView: View {
    let bundleID: String?
    let fallbackSymbol: String
    let size: CGFloat
    var fallbackSize: CGFloat?
    var fallbackColor: Color?

    @State private var icon: CGImage?
    @State private var isMissing = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            if let icon {
                Image(decorative: icon, scale: displayScale)
                    .resizable()
            } else if bundleID == nil || isMissing {
                let symbolSize = fallbackSize ?? size
                let symbol = Image(systemName: fallbackSymbol)
                    .resizable()
                    .scaledToFit()
                    .padding(symbolSize * DesignTokens.appIconSymbolInsetRatio)
                    .frame(width: symbolSize, height: symbolSize)
                if let fallbackColor {
                    symbol.foregroundStyle(fallbackColor)
                } else {
                    symbol.foregroundStyle(.secondary)
                }
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
    private let tints = Mutex<[String: AppIconTint?]>([:])

    func cachedTint(for bundleID: String) -> AppIconTint? {
        tints.withLock { $0[bundleID] }.flatMap(\.self)
    }

    @concurrent
    func tint(for bundleID: String) async -> AppIconTint? {
        if let cached = tints.withLock({ $0[bundleID] }) {
            return cached
        }
        let pixelSize = CGFloat(DesignTokens.appIconTintSampleSide)
        let tint = await icon(for: bundleID, pixelSize: pixelSize).flatMap(AppIconTint.init(icon:))
        tints.withLock { _ = $0.updateValue(tint, forKey: bundleID) }
        return tint
    }

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
