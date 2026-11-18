import SwiftUI

public struct MetadataStyle: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}

public extension View {
    func metadataStyle() -> some View {
        modifier(MetadataStyle())
    }
}
