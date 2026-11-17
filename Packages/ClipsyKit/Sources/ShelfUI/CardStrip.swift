import DesignSystem
import Store
import SwiftUI

struct CardStrip: View {
    let model: ShelfModel

    @State private var layout = CardLayout.regular
    @State private var isEntering = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(CardActions.self) private var actions

    var body: some View {
        TimelineView(.everyMinute) { context in
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: DesignTokens.cardSpacing) {
                        ForEach(model.cards.enumerated(), id: \.element.id) { index, card in
                            CardView(
                                card: card,
                                model: model,
                                now: context.date,
                                layout: layout,
                                match: model.searchResult(for: card.id),
                                board: model.board(of: card)
                            )
                            .cardEntrance(delay: entranceDelay(at: index))
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                                actions.cardFrames[card.id] = $0
                            }
                            .onDisappear { actions.cardFrames[card.id] = nil }
                            .transition(.scale(scale: DesignTokens.shelfOpenScale).combined(with: .opacity))
                        }
                    }
                    .scrollTargetLayout()
                    .animation(reduceMotion ? nil : .default, value: model.cards)
                }
                .contentMargins(DesignTokens.shelfPadding, for: .scrollContent)
                .onGeometryChange(for: CardLayout.self) { geometry in
                    CardLayout(stripHeight: geometry.size.height)
                } action: { newLayout in
                    withAnimation(reduceMotion ? nil : .default) {
                        layout = newLayout
                    }
                }
                .onScrollTargetVisibilityChange(idType: Int64.self, threshold: 0.5) { ids in
                    model.setVisibleCards(ids)
                }
                .onChange(of: model.cursorID) { _, cursorID in
                    guard let cursorID, cursorID != model.revealedID else { return }
                    withAnimation(reduceMotion ? nil : .default) {
                        proxy.scrollTo(cursorID)
                    }
                }
                .onChange(of: model.revealedID) { _, revealedID in
                    guard let revealedID else { return }
                    withAnimation(reduceMotion ? nil : .default) {
                        proxy.scrollTo(revealedID, anchor: .center)
                    }
                }
            }
        }
        .task {
            do {
                try await Task.sleep(for: DesignTokens.cardEntranceWindow)
            } catch {
                return
            }
            isEntering = false
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Cards", comment: "VoiceOver label of the card strip on the shelf"))
        .accessibilityValue(Text(
            "\(model.cards.count) cards",
            comment: "VoiceOver value of the card strip: the number of cards"
        ))
    }

    private func entranceDelay(at index: Int) -> TimeInterval? {
        guard isEntering, !reduceMotion else { return nil }
        return Double(min(index, DesignTokens.cardEntranceMaximumIndex)) * DesignTokens.cardEntranceStagger
    }
}
