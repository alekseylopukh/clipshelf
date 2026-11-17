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
    @Environment(BoardEditor.self) private var boardEditor
    @Environment(CardActions.self) private var actions
    @State private var height = DesignTokens.shelfDefaultHeight

    var body: some View {
        @Bindable var boardEditor = boardEditor
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
        .sheet(item: $boardEditor.draft) { draft in
            BoardEditorSheet(isNew: draft.boardID == nil)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .sheet(item: Bindable(actions).textEditor) { editor in
            TextCardEditorView(editor: editor, maxHeight: height)
        }
        .sheet(item: Bindable(actions).linkEditor) { editor in
            LinkCardEditorView(editor: editor, maxHeight: height)
        }
        .sheet(item: Bindable(actions).colorEditor) { editor in
            ColorCardEditorView(editor: editor, maxHeight: height)
        }
        .task(id: model.tab) {
            await model.observeCards()
        }
        .task {
            await model.observeBoards()
        }
        .task(id: model.searchKey) {
            await model.observeSearch()
        }
        .task {
            await model.observeApps()
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
    let boardEditor = BoardEditor(
        model: model,
        create: { _, _ in 0 },
        rename: { _, _ in },
        recolor: { _, _ in },
        move: { _, _ in },
        delete: { _ in },
        addCards: { _, _ in },
        moveCards: { _, _ in }
    )
    return ShelfContainerView(
        presentation: presentation,
        model: model,
        commands: ShelfCommands(),
        onResize: {},
        onResizeEnded: {}
    )
    .environment(CardActions())
    .environment(boardEditor)
    .frame(width: 800, height: 300)
    .padding()
}
