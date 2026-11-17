import SwiftUI

struct FadeTruncation: ViewModifier {
    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: DesignTokens.cardFadeHeight)
            }
        }
    }
}

public extension View {
    func fadeTruncation() -> some View {
        modifier(FadeTruncation())
    }
}
