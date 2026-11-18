import Testing
@testable import ShelfUI

struct AppIconCacheTests {
    @Test
    func `prewarming fills the tint and icon caches`() async {
        let cache = AppIconCache()
        let bundleID = "com.apple.finder"
        #expect(cache.cachedIcon(for: bundleID, pixelSize: 64) == nil)
        await cache.prewarm(bundleIDs: [bundleID], pixelSizes: [64])
        #expect(cache.cachedTint(for: bundleID) != nil)
        #expect(cache.cachedIcon(for: bundleID, pixelSize: 64) != nil)
    }
}
