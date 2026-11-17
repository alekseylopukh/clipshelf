import DesignSystem
import SwiftUI

struct ShelfResizeHandle: View {
    let onResize: () -> Void
    let onResizeEnded: () -> Void

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.shelfResizeHandleHeight)
            .contentShape(.rect)
            .pointerStyle(.frameResize(position: .top))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { _ in onResize() }
                    .onEnded { _ in onResizeEnded() }
            )
            .accessibilityHidden(true)
    }
}
