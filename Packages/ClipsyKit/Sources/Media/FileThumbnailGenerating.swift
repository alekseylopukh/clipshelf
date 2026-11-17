import CoreGraphics
import Foundation

public protocol FileThumbnailGenerating: Sendable {
    func thumbnail(of url: URL, pixelSize: CGFloat) async throws -> CGImage
}
