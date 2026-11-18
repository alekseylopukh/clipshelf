import SwiftUI

public struct TabTrackSegment<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID
    let isSelected: Bool
    let isTargeted: Bool

    @State private var isHovered = false

    public init(id: ID, in namespace: Namespace.ID, isSelected: Bool, isTargeted: Bool) {
        self.id = id
        self.namespace = namespace
        self.isSelected = isSelected
        self.isTargeted = isTargeted
    }

    public func body(content: Content) -> some View {
        content
            .lineLimit(1)
            .frame(maxWidth: DesignTokens.tabSegmentMaximumLabelWidth)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, DesignTokens.tabSegmentHorizontalPadding)
            .frame(height: DesignTokens.tabSegmentHeight)
            .background {
                if isTargeted {
                    Capsule().fill(Color.accentColor.opacity(DesignTokens.tabDropTargetOpacity))
                } else if isHovered, isSelected == false {
                    Capsule().fill(.fill.quaternary)
                }
            }
            .contentShape(.capsule)
            .onHover { isHovered = $0 }
            .matchedGeometryEffect(id: id, in: namespace)
            .sensoryFeedback(.alignment, trigger: isTargeted) { _, isTargeted in isTargeted }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

public extension View {
    func tabTrackSegment<ID: Hashable>(
        id: ID,
        in namespace: Namespace.ID,
        isSelected: Bool,
        isTargeted: Bool = false
    ) -> some View {
        modifier(TabTrackSegment(id: id, in: namespace, isSelected: isSelected, isTargeted: isTargeted))
    }
}
