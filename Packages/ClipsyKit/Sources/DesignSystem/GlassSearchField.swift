import SwiftUI

public struct GlassSearchField<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: DesignTokens.spacingSmall) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            content
        }
        .padding(.horizontal, DesignTokens.spacingLarge)
        .frame(minWidth: DesignTokens.searchFieldWidth, minHeight: DesignTokens.topBarControlHeight)
        .fixedSize(horizontal: true, vertical: false)
        .glassEffect(.regular, in: .capsule)
    }
}
