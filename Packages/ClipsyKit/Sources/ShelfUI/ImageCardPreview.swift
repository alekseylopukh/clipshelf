import DesignSystem
import os
import Store
import SwiftUI

struct ImageCardPreview: View {
    let card: CardSummary

    @State private var image: CGImage?
    @State private var isLoaded = false
    @Environment(\.cardMediaLoader) private var loader
    @Environment(\.displayScale) private var displayScale

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background {
                        if image.hasAlpha {
                            Checkerboard()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoaded {
                PlaceholderSymbol(card.kind.symbolName)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.fill.quaternary)
        .task(id: card.id) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let loader else { return }
        do {
            image = try await loader.image(of: card, maxPixelSize: DesignTokens.previewImageMaxPixelSize)
            isLoaded = true
        } catch is CancellationError {
            return
        } catch {
            isLoaded = true
            Self.logger.error("image preview failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
