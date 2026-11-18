import SwiftUI

public struct BorderlessIconMenuStyle: MenuStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .labelStyle(.iconOnly)
            .fixedSize()
    }
}

public extension MenuStyle where Self == BorderlessIconMenuStyle {
    static var borderlessIcon: BorderlessIconMenuStyle {
        BorderlessIconMenuStyle()
    }
}
