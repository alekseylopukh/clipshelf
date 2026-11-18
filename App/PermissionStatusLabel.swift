import DesignSystem
import SwiftUI

struct PermissionStatusLabel: View {
    let isAllowed: Bool

    var body: some View {
        Label {
            Text(isAllowed ? "Allowed" : "Not Allowed")
        } icon: {
            Image(systemName: isAllowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isAllowed ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .animation(DesignTokens.Motion.standard, value: isAllowed)
    }
}
