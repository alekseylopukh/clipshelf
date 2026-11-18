import DesignSystem
import SwiftUI

enum CardMediaFit {
    static func contentMode(imageSize: CGSize, bodySize: CGSize) -> ContentMode {
        guard imageSize.width > 0, imageSize.height > 0, bodySize.width > 0, bodySize.height > 0 else {
            return .fit
        }
        let ratio = (imageSize.width * bodySize.height) / (imageSize.height * bodySize.width)
        return DesignTokens.cardMediaFillAspectRange.contains(ratio) ? .fill : .fit
    }
}
