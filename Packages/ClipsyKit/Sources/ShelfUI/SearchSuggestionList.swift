import DesignSystem
import SwiftUI

struct SearchSuggestionList: View {
    let model: ShelfModel
    let width: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.suggestions) { token in
                SearchSuggestionRow(
                    token: token,
                    model: model,
                    isHighlighted: model.highlightedSuggestion == token
                )
            }
        }
        .padding(DesignTokens.spacingSmall)
        .frame(width: max(width, DesignTokens.searchFieldWidth))
        .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.searchSuggestionListCornerRadius))
        .glassEffectTransition(reduceMotion ? .identity : .materialize)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(
            "Filter Suggestions",
            comment: "VoiceOver name of the list of suggested search filters"
        ))
    }
}

private struct SearchSuggestionRow: View {
    let token: SearchToken
    let model: ShelfModel
    let isHighlighted: Bool

    var body: some View {
        Button {
            model.acceptSuggestion(token)
        } label: {
            HStack {
                SearchTokenLabel(token: token, title: model.title(of: token), boards: model.boards)
                Spacer()
                Text(token.category.name)
                    .foregroundStyle(.secondary)
            }
            .padding(DesignTokens.searchSuggestionInsets)
            .foregroundStyle(isHighlighted ? Color(nsColor: .alternateSelectedControlTextColor) : .primary)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: DesignTokens.searchSuggestionCornerRadius)
                        .fill(Color(nsColor: .selectedContentBackgroundColor))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                model.highlightedSuggestion = token
            }
        }
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }
}
