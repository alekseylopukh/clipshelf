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
        let pixelSize = size * displayScale
        let image = icon ?? bundleID.flatMap { AppIconCache.shared.cachedIcon(for: $0, pixelSize: pixelSize) }
        ZStack {
            if let image {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .transition(.opacity)
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
        .animation(DesignTokens.Motion.quick, value: image != nil)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: AppIconRequest(bundleID: bundleID, pixelSize: pixelSize)) {
            isMissing = false
            guard let bundleID else {
                icon = nil
                return
            }
            if let cached = AppIconCache.shared.cachedIcon(for: bundleID, pixelSize: pixelSize) {
                icon = cached
                return
            }
            icon = nil
            icon = await AppIconCache.shared.icon(for: bundleID, pixelSize: pixelSize)
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

    func cachedIcon(for bundleID: String, pixelSize: CGFloat) -> CGImage? {
        icons.withLock { $0[Self.key(bundleID, pixelSize)] }
    }

    @concurrent
    func prewarm(bundleIDs: [String], pixelSizes: [CGFloat]) async {
        await withTaskGroup(of: Void.self) { group in
            for bundleID in bundleIDs {
                group.addTask {
                    _ = await self.tint(for: bundleID)
                    for pixelSize in pixelSizes {
                        _ = await self.icon(for: bundleID, pixelSize: pixelSize)
                    }
                }
            }
        }
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
        let key = Self.key(bundleID, pixelSize)
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

    private static func key(_ bundleID: String, _ pixelSize: CGFloat) -> String {
        "\(bundleID)@\(Int(pixelSize))"
    }
}
