import SwiftUI

public struct AccessoryIconButtonStyle: PrimitiveButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .buttonStyle(.borderlessIcon)
            .foregroundStyle(.secondary)
    }
}

public extension PrimitiveButtonStyle where Self == AccessoryIconButtonStyle {
    static var accessoryIcon: AccessoryIconButtonStyle {
        AccessoryIconButtonStyle()
    }
}
