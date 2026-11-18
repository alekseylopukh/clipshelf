import SwiftUI

public struct EmptyStateView<Actions: View>: View {
    let title: Text
    let systemImage: String
    let description: Text?
    let actions: Actions

    public init(
        _ title: Text,
        systemImage: String,
        description: Text? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actions = actions()
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                title
            } icon: {
                Image(systemName: systemImage)
            }
        } description: {
            if let description {
                description
            }
        } actions: {
            actions
        }
    }
}

public extension EmptyStateView where Actions == EmptyView {
    init(_ title: Text, systemImage: String, description: Text? = nil) {
        self.init(title, systemImage: systemImage, description: description) {}
    }
}
