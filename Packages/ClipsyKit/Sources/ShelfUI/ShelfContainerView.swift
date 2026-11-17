import DesignSystem
import Store
import SwiftUI

struct ShelfContainerView: View {
    let presentation: ShelfPresentation
    let model: ShelfModel
    let commands: ShelfCommands
    let onResize: () -> Void
    let onResizeEnded: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if presentation.isVisible {
                VStack(spacing: 0) {
                    ShelfResizeHandle(onResize: onResize, onResizeEnded: onResizeEnded)
                    ShelfTopBar(model: model, commands: commands)
                        .padding(.horizontal, DesignTokens.shelfPadding)
                    ZStack {
                        CardStrip(model: model)
                        if let emptyState = model.emptyState(isCapturePaused: commands.isCapturePaused()) {
                            ShelfEmptyView(state: emptyState, commands: commands)
                        }
                    }
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
        .task {
            await model.observeBoards()
        }
    }

    private static let riseTransition: AnyTransition = .offset(y: DesignTokens.shelfOpenOffset)
        .combined(with: .scale(scale: DesignTokens.shelfOpenScale, anchor: .bottom))
        .combined(with: .opacity)
}

#Preview {
    let presentation = ShelfPresentation()
    presentation.isVisible = true
    let model = ShelfModel(
        observe: { _ in AsyncThrowingStream { $0.finish() } },
        observeBoards: { AsyncThrowingStream { $0.finish() } }
    )
    model.receive(CardSummary.previewCards)
    return ShelfContainerView(
        presentation: presentation,
        model: model,
        commands: ShelfCommands(),
        onResize: {},
        onResizeEnded: {}
    )
    .environment(CardActions())
    .frame(width: 800, height: 300)
    .padding()
}
