import SwiftUI

public struct BoardDot: View {
    let color: BoardColor
    let isOutlined: Bool

    public init(_ color: BoardColor, isOutlined: Bool = false) {
        self.color = color
        self.isOutlined = isOutlined
    }

    public var body: some View {
        Circle()
            .fill(color.color)
            .overlay {
                if isOutlined {
                    Circle().strokeBorder(
                        DesignTokens.cardHeaderBoardDotRing,
                        lineWidth: DesignTokens.boardDotOutlineWidth
                    )
                }
            }
            .frame(width: DesignTokens.boardDotSize, height: DesignTokens.boardDotSize)
    }
}
