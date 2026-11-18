import SwiftUI

public struct TabTrack<Selection: Hashable, Content: View>: View {
    let selection: Selection
    let label: Text
    let content: (Namespace.ID) -> Content

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    public init(selection: Selection, label: Text, @ViewBuilder content: @escaping (Namespace.ID) -> Content) {
        self.selection = selection
        self.label = label
        self.content = content
    }

    public var body: some View {
        HStack(spacing: DesignTokens.tabSegmentSpacing) {
            content(namespace)
        }
        .padding(DesignTokens.tabTrackPadding)
        .background {
            Capsule()
                .fill(.fill.secondary)
                .overlay {
                    if contrast == .increased {
                        Capsule().strokeBorder(Color(nsColor: .separatorColor))
                    }
                }
                .matchedGeometryEffect(id: selection, in: namespace, isSource: false)
        }
        .background(.fill.tertiary, in: .capsule)
        .animation(reduceMotion ? nil : DesignTokens.Motion.standard, value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}
