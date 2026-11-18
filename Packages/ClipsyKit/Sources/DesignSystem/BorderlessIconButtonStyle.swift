import SwiftUI

public struct BorderlessIconButtonStyle: PrimitiveButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
    }
}

public extension PrimitiveButtonStyle where Self == BorderlessIconButtonStyle {
    static var borderlessIcon: BorderlessIconButtonStyle {
        BorderlessIconButtonStyle()
    }
}
