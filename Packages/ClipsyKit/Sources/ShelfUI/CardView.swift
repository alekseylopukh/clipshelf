import AppKit
import DesignSystem
import Store
import SwiftUI

struct CardView: View {
    let card: CardSummary
    let model: ShelfModel
    let now: Date
    let layout: CardLayout
    private let content: CardContent

    @State private var isHovered = false
    @Environment(CardActions.self) private var actions

    init(card: CardSummary, model: ShelfModel, now: Date, layout: CardLayout) {
        self.card = card
        self.model = model
        self.now = now
        self.layout = layout
        content = CardContent(card)
    }

    var body: some View {
        let isSelected = model.selection.contains(card.id)
        CardSurface(
            card: card,
            content: content,
            now: now,
            layout: layout,
            isSelected: isSelected,
            isHovered: isHovered
        )
        .onHover { isHovered = $0 }
        .gesture(TapGesture(count: 2).onEnded { paste() })
        .simultaneousGesture(TapGesture().onEnded { click() })
        .contextMenu {
            CardContextMenu(cards: isSelected ? model.selectedCards : [card], list: model.tab)
        }
        .draggable(CardReference(cardID: card.id))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction { model.select(card.id) }
        .accessibilityActions {
            ForEach(CardCommand.menu(for: [card], in: model.tab).flatMap(\.self), id: \.self) { command in
                CardCommandButton(command: command, targetAppName: actions.targetAppName) {
                    actions.perform(command, [card.id])
                }
            }
        }
        .quickPasteBadge(model.quickPasteNumber(for: card.id))
    }

    private var accessibilityValue: Text {
        content.accessibilityValue(of: card).map { Text(verbatim: $0) } ?? Text(verbatim: "")
    }

    private var accessibilityLabel: Text {
        let time = Text(now, format: Date.AnchoredRelativeFormatStyle(
            anchor: card.displayDate,
            presentation: .named,
            unitsStyle: .wide
        ))
        if let app = card.sourceApp?.name {
            return Text(
                "\(card.kind.name) from \(app), \(time)",
                comment: "VoiceOver label of a card: type, source app and relative time, e.g. Text from TextEdit, 2 minutes ago"
            )
        }
        return Text(
            "\(card.kind.name), \(time)",
            comment: "VoiceOver label of a card without a source app: type and relative time"
        )
    }

    private func click() {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.control) {
            return
        }
        if modifiers.contains(.command) {
            model.toggleSelection(of: card.id)
        } else if modifiers.contains(.shift) {
            model.extendSelection(to: card.id)
        } else {
            model.select(card.id)
        }
    }

    private func paste() {
        let command: CardCommand = NSEvent.modifierFlags.contains(.shift) ? .pasteAsPlainText : .paste
        actions.perform(command, [card.id])
    }
}

private struct CardSurface: View {
    let card: CardSummary
    let content: CardContent
    let now: Date
    let layout: CardLayout
    let isSelected: Bool
    let isHovered: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.pixelLength) private var pixelLength

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: layout == .compact ? DesignTokens.spacingSmall : DesignTokens.spacingMedium
        ) {
            CardHeader(card: card, now: now, layout: layout)
            CardBodyView(card: card, content: content)
            if layout == .regular {
                CardFooter(kind: card.kind, content: content)
            }
        }
        .padding(DesignTokens.cardContentInsets)
        .frame(maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Color(nsColor: DesignTokens.cardFill), in: shape)
        .overlay {
            shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: pixelLength)
        }
        .overlay {
            if isSelected {
                SelectionRing(width: DesignTokens.selectionRingWidth(for: contrast))
            }
        }
        .contentShape(.dragPreview, shape)
        .contentShape(shape)
        .scaleEffect(isSelected ? DesignTokens.cardLiftScale : 1)
        .shadow(
            color: isHovered || isSelected ? DesignTokens.cardLiftShadowColor : .clear,
            radius: DesignTokens.cardLiftShadowRadius,
            y: DesignTokens.cardLiftShadowOffset
        )
        .animation(reduceMotion ? nil : .default, value: isSelected)
        .animation(reduceMotion ? nil : .default, value: isHovered)
    }
}

private struct SelectionRing: View {
    let width: CGFloat

    var body: some View {
        let outset = DesignTokens.selectionRingGap + width
        RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius + outset)
            .strokeBorder(Color.accentColor, lineWidth: width)
            .padding(-outset)
            .accessibilityHidden(true)
    }
}

private struct CardPreview: View {
    let card: CardSummary
    var isSelected = false
    var layout = CardLayout.regular
    @State private var model = ShelfModel { _ in AsyncThrowingStream { $0.finish() } }

    var body: some View {
        let compactHeight = DesignTokens.shelfMinimumHeight - DesignTokens.shelfResizeHandleHeight
            - 2 * DesignTokens.shelfPadding
        CardView(card: card, model: model, now: .now, layout: layout)
            .frame(height: layout == .compact ? compactHeight : DesignTokens.cardSide)
            .padding(DesignTokens.shelfPadding)
            .environment(CardActions())
            .environment(\.richTextLoader, RichTextLoader { _ in
                let text = NSAttributedString(string: "Quarterly plan\nShip the shelf by Friday.", attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 24),
                    .foregroundColor: NSColor.systemIndigo
                ])
                let data = try text.data(
                    from: NSRange(location: 0, length: text.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
                return [Representation(itemIndex: 0, uti: NSPasteboard.PasteboardType.rtf.rawValue, data: data)]
            })
            .task {
                model.receive([card])
                if isSelected {
                    model.select(card.id)
                }
            }
    }
}

#Preview("Plain text") {
    CardPreview(card: CardSummary.previewCards[0], isSelected: true)
}

#Preview("Compact") {
    CardPreview(card: CardSummary.previewCards[0], isSelected: true, layout: .compact)
}

#Preview("Rich text") {
    CardPreview(card: CardSummary(id: 9, kind: .text, preview: "Quarterly plan", createdAt: .now))
}

#Preview("Code-like text") {
    CardPreview(card: CardSummary.previewCards[1])
}

#Preview("Link") {
    CardPreview(card: CardSummary.previewCards[2])
}

#Preview("Color") {
    CardPreview(card: CardSummary.previewCards[3])
}

#Preview("Unknown") {
    CardPreview(card: CardSummary.previewCards[4])
}
