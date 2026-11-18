import AppKit
import DesignSystem
import SwiftUI

struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var credits: AttributedString?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                if let credits {
                    Text(credits)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignTokens.onboardingPadding)
                }
            }
            Divider()
            SheetButtonBar {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(DesignTokens.spacingLarge)
        }
        .frame(width: DesignTokens.acknowledgementsWidth, height: DesignTokens.acknowledgementsHeight)
        .task {
            credits = await Self.loadCredits()
        }
    }

    @concurrent
    private static func loadCredits() async -> AttributedString {
        guard let url = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
              let text = try? NSAttributedString(url: url, options: [:], documentAttributes: nil),
              let credits = try? AttributedString(text, including: \.appKit)
        else {
            fatalError("Credits.rtf ships in the app bundle as valid RTF")
        }
        return credits
    }
}
