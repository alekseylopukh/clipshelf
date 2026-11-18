import CoreGraphics
import DesignSystem

enum PreviewKind: Equatable {
    case text(isCodeLike: Bool)
    case linkWithImage
    case link
    case color
    case image(pixelSize: CGSize?)
    case file
    case files(count: Int)
    case unavailable
}

/// `height` nil makes the preview as tall as its content
struct PreviewFrame: Equatable {
    var width: CGFloat
    var height: CGFloat?
    var maximumHeight: CGFloat
}

struct PreviewSizeCalculator {
    var defaultSize = CGSize(width: DesignTokens.previewWidth, height: DesignTokens.previewHeight)
    var minimumSide = DesignTokens.previewMinimumSide
    var margin = DesignTokens.previewScreenMargin

    func availableSize(in visibleFrame: CGRect, above shelfGlassFrame: CGRect) -> CGSize {
        CGSize(
            width: visibleFrame.width - 2 * margin,
            height: visibleFrame.maxY - shelfGlassFrame.maxY - margin
        )
    }

    func frame(for kind: PreviewKind, in available: CGSize) -> PreviewFrame {
        let maximumWidth = min(defaultSize.width, available.width)
        let maximumHeight = min(defaultSize.height, available.height)
        let width: CGFloat
        var height: CGFloat?
        switch kind {
        case let .text(isCodeLike):
            width = isCodeLike ? DesignTokens.previewCodeWidth : DesignTokens.previewTextWidth
        case .linkWithImage, .link:
            width = DesignTokens.previewLinkWidth
        case .color:
            width = DesignTokens.previewColorWidth
        case let .image(pixelSize):
            let size = size(in: available, imagePixelSize: pixelSize)
            width = size.width
            height = size.height
        case .file:
            let size = size(in: available)
            width = size.width
            height = size.height
        case let .files(count):
            width = DesignTokens.previewFilesWidth
            height = DesignTokens.previewFileRowHeight * CGFloat(min(count, DesignTokens.previewFilesMaximumRows))
        case .unavailable:
            width = DesignTokens.previewUnavailableSize.width
            height = DesignTokens.previewUnavailableSize.height
        }
        return PreviewFrame(
            width: min(width, maximumWidth),
            height: height.map { min($0, maximumHeight) },
            maximumHeight: maximumHeight
        )
    }

    func size(in available: CGSize, imagePixelSize: CGSize? = nil) -> CGSize {
        let scale = min(1, available.width / defaultSize.width, available.height / defaultSize.height)
        let box = CGSize(width: defaultSize.width * scale, height: defaultSize.height * scale)
        guard let imagePixelSize else {
            return CGSize(width: box.width.rounded(.down), height: box.height.rounded(.down))
        }
        let fit = min(box.width / imagePixelSize.width, box.height / imagePixelSize.height)
        let width = min(max(imagePixelSize.width * fit, minimumSide), box.width)
        let height = min(max(imagePixelSize.height * fit, minimumSide), box.height)
        return CGSize(width: width.rounded(.down), height: height.rounded(.down))
    }
}
