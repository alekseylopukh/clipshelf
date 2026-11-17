import CoreGraphics
import DesignSystem
import Testing

struct DesignTokensTests {
    @Test func `increase contrast thickens the selection ring by one point`() {
        let standard = DesignTokens.selectionRingWidth(for: .standard)
        #expect(DesignTokens.selectionRingWidth(for: .increased) == standard + 1)
    }
}
