import SwiftUI

public struct SheetHeader: View {
    let title: Text

    public init(_ title: Text) {
        self.title = title
    }

    public var body: some View {
        title
            .font(.headline)
    }
}
