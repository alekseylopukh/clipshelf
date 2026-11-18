import DesignSystem
import os
import Store
import SwiftUI

struct ImageCardPreview: View {
    let card: CardSummary

    @State private var thumbnail: CGImage?
    @State private var image: CGImage?
    @State private var isLoaded = false
    @State private var isSpinnerVisible = false
    @Environment(\.cardMediaLoader) private var loader
    @Environment(\.displayScale) private var displayScale

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    var body: some View {
        ZStack {
            if let image {
                PreviewImage(image: image, scale: displayScale)
                    .transition(.opacity)
            } else if let thumbnail {
                PreviewImage(image: thumbnail, scale: 1)
                    .transition(.opacity)
            } else if isLoaded {
                PlaceholderSymbol(card.kind.symbolName)
            } else if isSpinnerVisible {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(DesignTokens.Motion.quick, value: image != nil)
        .task(id: card.id) {
            await loadImage()
        }
        .task(id: card.id) {
            do {
                try await Task.sleep(for: DesignTokens.previewSpinnerDelay)
            } catch {
                return
            }
            isSpinnerVisible = true
        }
    }

    private func loadImage() async {
        guard let loader else { return }
        async let full = loader.image(of: card, maxPixelSize: DesignTokens.previewImageMaxPixelSize)
        if let hash = card.contentHash {
            do {
                thumbnail = try await loader.thumbnail(
                    of: card,
                    hash: hash,
                    maxPixelSize: DesignTokens.thumbnailMaxPixelSize
                )
            } catch is CancellationError {
                return
            } catch {
                Self.logger.error("image thumbnail failed: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
        do {
            image = try await full
            isLoaded = true
        } catch is CancellationError {
            return
        } catch {
            isLoaded = true
            Self.logger.error("image preview failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}

private struct PreviewImage: View {
    let image: CGImage
    let scale: CGFloat

    var body: some View {
        Image(decorative: image, scale: scale)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .background {
                if image.hasAlpha {
                    Checkerboard()
                }
            }
    }
}
