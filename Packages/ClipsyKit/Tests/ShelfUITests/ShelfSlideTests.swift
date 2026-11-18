import AppKit
import DesignSystem
import Testing
@testable import ShelfUI

@MainActor
struct ShelfSlideTests {
    private let view = NSView(frame: CGRect(x: 0, y: 0, width: 800, height: 388))

    @Test func `sliding in starts below the window and ends in place`() throws {
        let slide = ShelfSlide()
        slide.attach(to: view, in: NSPanel())

        slide.slideIn(distance: 388)

        let animation = try #require(view.layer?.animation(forKey: ShelfSlide.key) as? CASpringAnimation)
        #expect(animation.fromValue as? CGFloat == -388)
        #expect(animation.toValue as? CGFloat == 0)
    }

    @Test func `sliding out holds the content below the window until reset`() throws {
        let slide = ShelfSlide()
        slide.attach(to: view, in: NSPanel())

        let duration = slide.slideOut(distance: 388)

        let animation = try #require(view.layer?.animation(forKey: ShelfSlide.key) as? CABasicAnimation)
        #expect(duration == DesignTokens.shelfCloseSlideDuration)
        #expect(animation.toValue as? CGFloat == -388)
        #expect(animation.isRemovedOnCompletion == false)

        slide.reset()

        #expect(view.layer?.animation(forKey: ShelfSlide.key) == nil)
    }

    @Test func `with Reduce Motion the panel fades instead of sliding`() {
        let slide = ShelfSlide()
        slide.attach(to: view, in: NSPanel())
        slide.slideIn(distance: 388)

        slide.open(reduceMotion: true)

        #expect(view.layer?.animation(forKey: ShelfSlide.key) == nil)
        #expect(slide.close(reduceMotion: true) == DesignTokens.shelfReducedFadeDuration)
        #expect(view.layer?.animation(forKey: ShelfSlide.key) == nil)
    }
}
