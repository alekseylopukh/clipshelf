import SwiftUI

public struct Checkerboard: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let side = DesignTokens.checkerboardSquareSize
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(nsColor: .textBackgroundColor)))
            var squares = Path()
            for row in 0 ..< Int((size.height / side).rounded(.up)) {
                for column in stride(from: row % 2, to: Int((size.width / side).rounded(.up)), by: 2) {
                    squares.addRect(CGRect(
                        x: CGFloat(column) * side,
                        y: CGFloat(row) * side,
                        width: side,
                        height: side
                    ))
                }
            }
            context.fill(squares, with: .color(Color(nsColor: .quaternaryLabelColor)))
        }
        .accessibilityHidden(true)
    }
}
