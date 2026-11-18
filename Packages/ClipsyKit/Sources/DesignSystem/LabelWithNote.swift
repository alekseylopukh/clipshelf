import SwiftUI

/// grouped forms draw the second text of a row label as its secondary note
public struct LabelWithNote: View {
    let title: Text
    let note: Text

    public init(_ title: Text, note: Text) {
        self.title = title
        self.note = note
    }

    public var body: some View {
        title
        note
    }
}
