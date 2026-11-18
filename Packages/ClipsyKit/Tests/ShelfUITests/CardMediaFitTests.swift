import CoreGraphics
import SwiftUI
import Testing
@testable import ShelfUI

struct CardMediaFitTests {
    private static let bodySize = CGSize(width: 224, height: 160)

    @Test(arguments: [
        (ratio: 0.49, expected: ContentMode.fit),
        (ratio: 0.5, expected: .fill),
        (ratio: 1, expected: .fill),
        (ratio: 2, expected: .fill),
        (ratio: 2.01, expected: .fit)
    ])
    func `fills within the aspect range`(ratio: CGFloat, expected: ContentMode) {
        let imageSize = CGSize(width: Self.bodySize.width * ratio, height: Self.bodySize.height)
        #expect(CardMediaFit.contentMode(imageSize: imageSize, bodySize: Self.bodySize) == expected)
    }

    @Test(arguments: [
        (image: CGSize.zero, body: bodySize),
        (image: CGSize(width: 100, height: 100), body: .zero)
    ])
    func `fits an empty size`(image: CGSize, body: CGSize) {
        #expect(CardMediaFit.contentMode(imageSize: image, bodySize: body) == .fit)
    }
}
