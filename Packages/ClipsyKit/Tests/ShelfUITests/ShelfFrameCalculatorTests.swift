import CoreGraphics
import Testing
@testable import ShelfUI

struct ShelfFrameCalculatorTests {
    private let calculator = ShelfFrameCalculator(
        inset: 10,
        shadowMargin: 20,
        minimumHeight: 160,
        maximumHeightFraction: 0.4
    )

    @Test func `glass frame is inset above dock`() {
        let visibleFrame = CGRect(x: 0, y: 70, width: 1440, height: 806)

        let frame = calculator.glassFrame(height: 300, in: visibleFrame)

        #expect(frame == CGRect(x: 10, y: 80, width: 1420, height: 300))
    }

    @Test func `glass frame follows visible frame of secondary display`() {
        let visibleFrame = CGRect(x: -1920, y: 200, width: 1920, height: 1055)

        let frame = calculator.glassFrame(height: 300, in: visibleFrame)

        #expect(frame == CGRect(x: -1910, y: 210, width: 1900, height: 300))
    }

    @Test func `window frame leaves shadow margin around glass`() {
        let visibleFrame = CGRect(x: 0, y: 70, width: 1440, height: 806)

        let frame = calculator.windowFrame(height: 300, in: visibleFrame)

        #expect(frame == CGRect(x: -10, y: 60, width: 1460, height: 340))
    }

    @Test func `glass height round-trips through window frame`() {
        let visibleFrame = CGRect(x: 0, y: 70, width: 1440, height: 806)

        let frame = calculator.windowFrame(height: 250, in: visibleFrame)

        #expect(calculator.glassHeight(windowHeight: frame.height) == 250)
    }

    @Test(arguments: [
        (requested: 40.0, expected: 160.0),
        (requested: 250.0, expected: 250.0),
        (requested: 900.0, expected: 400.0)
    ])
    func `height is clamped to range`(requested: CGFloat, expected: CGFloat) {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1600, height: 1000)

        #expect(calculator.clampedHeight(requested, in: visibleFrame) == expected)
    }

    @Test func `minimum height wins on short display`() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 800, height: 300)

        #expect(calculator.clampedHeight(500, in: visibleFrame) == 160)
    }
}
