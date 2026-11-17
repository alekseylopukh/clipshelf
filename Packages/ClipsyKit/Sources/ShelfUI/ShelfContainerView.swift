import DesignSystem
import SwiftUI

struct ShelfContainerView: View {
    let presentation: ShelfPresentation
    let model: ShelfModel
    let onResize: () -> Void
    let onResizeEnded: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if presentation.isVisible {
                VStack(spacing: 0) {
                    ShelfResizeHandle(onResize: onResize, onResizeEnded: onResizeEnded)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.shelfCornerRadius))
                .transition(reduceMotion ? .opacity : Self.riseTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: model.tab) {
            await model.observeCards()
        }
    }

    private static let riseTransition: AnyTransition = .offset(y: DesignTokens.shelfOpenOffset)
        .combined(with: .scale(scale: DesignTokens.shelfOpenScale, anchor: .bottom))
        .combined(with: .opacity)
}

#Preview {
    let presentation = ShelfPresentation()
    presentation.isVisible = true
    let model = ShelfModel { _ in AsyncThrowingStream { $0.finish() } }
    return ShelfContainerView(presentation: presentation, model: model, onResize: {}, onResizeEnded: {})
        .frame(width: 800, height: 300)
        .padding()
}
