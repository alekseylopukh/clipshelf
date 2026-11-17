import DesignSystem
import Store
import SwiftUI

struct CardStrip: View {
    let model: ShelfModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.everyMinute) { context in
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: DesignTokens.cardSpacing) {
                        ForEach(model.cards) { card in
                            CardView(card: card, model: model, now: context.date)
                                .transition(.scale(scale: DesignTokens.shelfOpenScale).combined(with: .opacity))
                        }
                    }
                    .scrollTargetLayout()
                    .animation(reduceMotion ? nil : .default, value: model.cards)
                }
                .contentMargins(DesignTokens.shelfPadding, for: .scrollContent)
                .onScrollTargetVisibilityChange(idType: Int64.self, threshold: 0.5) { ids in
                    model.setVisibleCards(ids)
                }
                .onChange(of: model.cursorID) { _, cursorID in
                    guard let cursorID else { return }
                    withAnimation(reduceMotion ? nil : .default) {
                        proxy.scrollTo(cursorID)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Cards", comment: "VoiceOver label of the card strip on the shelf"))
        .accessibilityValue(Text(
            "\(model.cards.count) cards",
            comment: "VoiceOver value of the card strip: the number of cards"
        ))
    }
}
