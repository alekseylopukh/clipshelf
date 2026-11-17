import CoreGraphics
import Testing
@testable import ShelfUI

struct PreviewSizeCalculatorTests {
    private let calculator = PreviewSizeCalculator(
        defaultSize: CGSize(width: 880, height: 680),
        minimumSide: 240,
        margin: 16
    )

    @Test func `available size is the space above the shelf inside the margins`() {
        let visibleFrame = CGRect(x: 0, y: 70, width: 1470, height: 848)
        let glassFrame = CGRect(x: 8, y: 78, width: 1454, height: 300)

        let available = calculator.availableSize(in: visibleFrame, above: glassFrame)

        #expect(available == CGSize(width: 1438, height: 524))
    }

    @Test func `available size follows a secondary display`() {
        let visibleFrame = CGRect(x: -1920, y: 200, width: 1920, height: 1055)
        let glassFrame = CGRect(x: -1912, y: 208, width: 1904, height: 300)

        let available = calculator.availableSize(in: visibleFrame, above: glassFrame)

        #expect(available == CGSize(width: 1888, height: 731))
    }

    @Test func `big screen gets the default size`() {
        #expect(calculator.size(in: CGSize(width: 1696, height: 755)) == CGSize(width: 880, height: 680))
    }

    @Test func `small screen clamps the size and keeps the aspect ratio`() {
        let size = calculator.size(in: CGSize(width: 1438, height: 524))

        #expect(size == CGSize(width: 678, height: 524))
    }

    @Test func `narrow screen clamps by width`() {
        let size = calculator.size(in: CGSize(width: 440, height: 900))

        #expect(size == CGSize(width: 440, height: 340))
    }

    @Test(arguments: [
        (image: CGSize(width: 1000, height: 3000), expected: CGSize(width: 240, height: 680)),
        (image: CGSize(width: 1500, height: 3000), expected: CGSize(width: 340, height: 680)),
        (image: CGSize(width: 3000, height: 1000), expected: CGSize(width: 880, height: 293)),
        (image: CGSize(width: 1600, height: 1000), expected: CGSize(width: 880, height: 550)),
        (image: CGSize(width: 10000, height: 100), expected: CGSize(width: 880, height: 240))
    ])
    func `image fits its aspect ratio inside the default box`(image: CGSize, expected: CGSize) {
        #expect(calculator.size(in: CGSize(width: 1696, height: 755), imagePixelSize: image) == expected)
    }

    @Test func `image fits inside the clamped box`() {
        let size = calculator.size(
            in: CGSize(width: 1438, height: 524),
            imagePixelSize: CGSize(width: 1000, height: 2000)
        )

        #expect(size == CGSize(width: 262, height: 524))
    }

    @Test func `minimum size never exceeds the clamped box`() {
        let size = calculator.size(
            in: CGSize(width: 1438, height: 150),
            imagePixelSize: CGSize(width: 1000, height: 3000)
        )

        #expect(size == CGSize(width: 194, height: 150))
    }
}
