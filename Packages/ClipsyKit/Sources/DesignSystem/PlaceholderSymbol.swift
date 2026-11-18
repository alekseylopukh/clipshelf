import SwiftUI

public struct PlaceholderSymbol: View {
    let systemName: String

    public init(_ systemName: String) {
        self.systemName = systemName
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.largeTitle)
            .foregroundStyle(.secondary)
    }
}
