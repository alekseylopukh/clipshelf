import SwiftUI

struct PermissionStatusLabel: View {
    let isAllowed: Bool

    var body: some View {
        if isAllowed {
            Label {
                Text("Allowed")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } else {
            Label {
                Text("Not Allowed")
            } icon: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
