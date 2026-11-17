import CoreGraphics
import Testing
@testable import Pasting

struct PasteLandingLocatorTests {
    private struct FakeReader: FocusGeometryReading {
        var caret: CGRect?
        var element: CGRect?
        var window: CGRect?

        func caretBounds(in _: pid_t) -> CGRect? {
            caret
        }

        func focusedElementFrame(in _: pid_t) -> CGRect? {
            element
        }

        func focusedWindowFrame(in _: pid_t) -> CGRect? {
            window
        }
    }

    private static let caret = CGRect(x: 300, y: 100, width: 1, height: 18)
    private static let element = CGRect(x: 200, y: 80, width: 400, height: 60)
    private static let window = CGRect(x: 100, y: 40, width: 800, height: 600)

    @Test func `converts accessibility coordinates to AppKit screen coordinates`() {
        let rect = PasteLandingLocator.appKitRect(
            fromAccessibility: CGRect(x: 100, y: 200, width: 2, height: 20),
            primaryScreenHeight: 1000
        )

        #expect(rect == CGRect(x: 100, y: 780, width: 2, height: 20))
    }

    @Test func `converts a rect on a display above the primary one`() {
        let rect = PasteLandingLocator.appKitRect(
            fromAccessibility: CGRect(x: 50, y: -900, width: 10, height: 100),
            primaryScreenHeight: 1000
        )

        #expect(rect == CGRect(x: 50, y: 1800, width: 10, height: 100))
    }

    @Test(arguments: [
        (FakeReader(caret: caret, element: element, window: window), caret),
        (FakeReader(caret: nil, element: element, window: window), element),
        (FakeReader(caret: .zero, element: element, window: window), element),
        (FakeReader(caret: nil, element: nil, window: window), window),
        (FakeReader(caret: nil, element: CGRect(x: 1, y: 1, width: 5, height: 0), window: window), window)
    ])
    private func `falls back from caret to element to window`(reader: FakeReader, expected: CGRect) {
        let locator = PasteLandingLocator(reader: reader)

        let rect = locator.locate(in: 1, primaryScreenHeight: 1000)

        #expect(rect == PasteLandingLocator.appKitRect(fromAccessibility: expected, primaryScreenHeight: 1000))
    }

    @Test func `finds no landing when the app exposes no geometry`() {
        let locator = PasteLandingLocator(reader: FakeReader())

        #expect(locator.locate(in: 1, primaryScreenHeight: 1000) == nil)
    }
}
