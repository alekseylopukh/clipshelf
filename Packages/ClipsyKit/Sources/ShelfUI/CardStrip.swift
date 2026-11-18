import DesignSystem
import Store
import SwiftUI

struct CardStrip: View {
    let model: ShelfModel

    @State private var layout = CardLayout.regular
    @State private var hasMeasuredLayout = false
    @State private var isEntering = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(CardActions.self) private var actions

    var body: some View {
        TimelineView(.everyMinute) { context in
            ScrollViewReader { proxy in
                ZStack {
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
                                .cardEntrance(delay: isEntering && !reduceMotion ? CardEntrance.delay(at: index) : nil)
                                .scrollTransition(
                                    .interactive.threshold(.visible(DesignTokens.cardVisibilityThreshold)),
                                    axis: .horizontal
                                ) { content, phase in
                                    content.opacity(phase.isIdentity ? 1 : DesignTokens.stripEdgeOpacity)
                                }
                                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                                    actions.cardFrames[card.id] = $0
                                }
                                .onDisappear { actions.cardFrames[card.id] = nil }
                                .transition(Self.cardTransition(
                                    arrival: model.arrival,
                                    isSearching: model.isSearching,
                                    reduceMotion: reduceMotion
                                ))
                            }
                        }
                        .scrollTargetLayout()
                        .animation(reduceMotion ? nil : DesignTokens.Motion.standard, value: model.cards)
                    }
                    .contentMargins(DesignTokens.shelfPadding, for: .scrollContent)
                    .onGeometryChange(for: CardLayout.self) { geometry in
                        CardLayout(stripHeight: geometry.size.height)
                    } action: { newLayout in
                        guard hasMeasuredLayout else {
                            layout = newLayout
                            hasMeasuredLayout = true
                            return
                        }
                        withAnimation(reduceMotion ? nil : DesignTokens.Motion.standard) {
                            layout = newLayout
                        }
                    }
                    .onScrollTargetVisibilityChange(
                        idType: Int64.self,
                        threshold: DesignTokens.cardVisibilityThreshold
                    ) { ids in
                        model.setVisibleCards(ids)
                    }
                    .id(model.tab)
                    .transition(.opacity)
                }
                .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.quick, value: model.tab)
                .onChange(of: model.cursorID) { _, cursorID in
                    guard let cursorID, cursorID != model.revealedID else { return }
                    withAnimation(reduceMotion ? nil : DesignTokens.Motion.quick) {
                        proxy.scrollTo(cursorID)
                    }
                }
                .onChange(of: model.revealedID) { _, revealedID in
                    guard let revealedID else { return }
                    withAnimation(reduceMotion ? nil : DesignTokens.Motion.standard) {
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

    static func cardTransition(arrival: CardsArrival, isSearching: Bool, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return AnyTransition.opacity.animation(DesignTokens.Motion.reduced) }
        let insertion = switch arrival {
        case let .tab(fromLeading):
            AnyTransition.offset(x: fromLeading ? -DesignTokens.cardTabSlideOffset : DesignTokens.cardTabSlideOffset)
                .combined(with: .opacity)
                .animation(DesignTokens.Motion.standard)
        case .edit:
            AnyTransition.scale(scale: DesignTokens.cardInsertScale)
                .combined(with: .opacity)
                .animation(DesignTokens.Motion.pop.delay(DesignTokens.cardInsertDelay))
        case .search, .load:
            AnyTransition.opacity.animation(DesignTokens.Motion.quick)
        }
        let removal: AnyTransition = isSearching
            ? .opacity
            : .scale(scale: DesignTokens.cardRemoveScale).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal.animation(DesignTokens.Motion.quick))
    }
}
