import DesignSystem
import SwiftUI

struct LinkCardPreview: View {
    let title: String?
    let host: String?
    let url: String?

    var body: some View {
        VStack(spacing: DesignTokens.spacingMedium) {
            Image(systemName: "link")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .padding(.bottom, DesignTokens.spacingMedium)
            if let heading = title ?? host {
                Text(verbatim: heading)
                    .font(.title3.weight(.semibold))
            }
            if let url {
                Text(verbatim: url)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
