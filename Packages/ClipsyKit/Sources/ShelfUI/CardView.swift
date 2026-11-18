import AppKit
import DesignSystem
import Store
import SwiftUI

struct CardView: View {
    let card: CardSummary
    let model: ShelfModel
    let now: Date
    let layout: CardLayout
    let board: Board?
    private let content: CardContent
    private let highlights: CardHighlights

    @State private var size = CGSize.zero
    @State private var openWithApplications: [OpenWithApplication] = []
    @Environment(CardActions.self) private var actions
    @Environment(BoardEditor.self) private var boardEditor

    init(
        card: CardSummary,
        model: ShelfModel,
        now: Date,
        layout: CardLayout,
        match: SearchResult? = nil,
        board: Board? = nil
    ) {
        self.card = card
        self.model = model
        self.now = now
        self.layout = layout
        self.board = board
        content = CardContent(card)
        highlights = CardHighlights(card: card, match: match)
    }

    var body: some View {
        let isSelected = model.selection.contains(card.id)
        CardFace(
            card: card,
            content: content,
            highlights: highlights,
            board: board,
            now: now,
            layout: layout,
            isSelected: isSelected
        )
        .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
        .background {
            if model.cursorID == card.id {
                CardPreviewAnchor()
            }
        }
        .gesture(TapGesture(count: 2).onEnded { actions.pasteOnDoubleClick([card.id]) })
        .simultaneousGesture(TapGesture().onEnded { click() })
        .contextMenu {
            let cards = isSelected ? model.selectedCards : [card]
            CardContextMenu(
                cards: cards,
                list: model.removalList(for: cards.map(\.id)),
                isSearchResult: model.isSearching,
                openWithApplications: openWithApplications
            )
        }
        .task(id: card.id) {
            openWithApplications = await OpenWithApplication.applications(for: card)
        }
        .simultaneousGesture(DragGesture().onChanged { value in
            actions.beginDrag(CardDrag(
                cardIDs: isSelected ? model.selectedCards.map(\.id) : [card.id],
                cardSize: size,
                pointer: value.location
            ))
        })
        .dropDestination(
            for: CardReference.self,
            isEnabled: model.tab != .history && !model.isSearching
        ) { references, _ in
            let ids = references.cardIDs
            Task {
                await boardEditor.reorder(ids, onto: card.id)
            }
        }
        .cardRenamePopover(for: card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityCustomContent(
            AccessibilityCustomContentKey(
                Text("Board", comment: "VoiceOver name of the board a search result is on"),
                id: "board"
            ),
            board.map { Text(verbatim: $0.name) }
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction { model.select(card.id) }
        .accessibilityActions {
            ForEach(accessibilityCommands, id: \.self) { command in
                CardCommandButton(
                    command: command,
                    cards: [card],
                    targetAppName: actions.targetAppName,
                    plainTextModifiers: actions.plainTextModifier.eventModifiers,
                    isCopyAsPlainTextShortcutTaken: actions.isCopyAsPlainTextShortcutTaken
                ) {
                    actions.perform(command, [card.id])
                }
            }
            ForEach(boardEditor.boards(forAdding: [card])) { board in
                Button(String(
                    localized: "Add to \(board.name)",
                    comment: "VoiceOver action of a card that adds it to the named board"
                )) {
                    Task {
                        await boardEditor.add([card.id], to: board.id)
                    }
                }
            }
            Button(String(
                localized: "Add to New Board…",
                comment: "VoiceOver action of a card that creates a board for it"
            )) {
                boardEditor.beginNew(adding: [card.id])
            }
        }
        .quickPasteBadge(model.quickPasteNumber(for: card.id))
        .cardPopUpAnchor(for: card)
    }

    /// add to board is a submenu, so voiceover gets one action per board instead; open with stays on ⇧⌘O
    private var accessibilityCommands: [CardCommand] {
        CardCommand.menu(for: [card], in: model.list(of: card), isSearchResult: model.isSearching)
            .joined()
            .filter { $0 != .addToBoard && $0 != .openWith }
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
}

private struct CardFace: View {
    let card: CardSummary
    let content: CardContent
    let highlights: CardHighlights
    let board: Board?
    let now: Date
    let layout: CardLayout
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(card: card, now: now, layout: layout, highlightedTitle: highlights.title, board: board)
            CardBodyView(card: card, content: content, layout: layout, highlightedPreview: highlights.preview)
            if CardFooter.isShown(for: card.kind, layout: layout) {
                CardFooter(kind: card.kind, content: content)
                    .padding(.top, DesignTokens.spacingMedium)
            }
        }
        .padding(DesignTokens.cardContentInset)
        .frame(maxHeight: .infinity)
        .aspectRatio(layout == .compact ? DesignTokens.compactCardAspectRatio : 1, contentMode: .fit)
        .cardSurface(isSelected: isSelected)
    }
}

private struct CardHighlights {
    let title: AttributedString?
    let preview: AttributedString?

    init(card: CardSummary, match: SearchResult?) {
        title = card.title.flatMap { SearchHighlight.text($0, matches: match?.titleMatches ?? []) }
        preview = card.preview.flatMap { SearchHighlight.text($0, matches: match?.previewMatches ?? []) }
    }
}

private struct CardPreview: View {
    let card: CardSummary
    var isSelected = false
    var layout = CardLayout.regular
    @State private var model = ShelfModel(
        observe: { _ in AsyncThrowingStream { $0.finish() } },
        observeBoards: { AsyncThrowingStream { $0.finish() } }
    )

    var body: some View {
        let compactHeight = DesignTokens.shelfMinimumHeight - DesignTokens.topBarControlHeight
            - 3 * DesignTokens.shelfPadding
        CardView(card: card, model: model, now: .now, layout: layout)
            .frame(height: layout == .compact ? compactHeight : DesignTokens.cardSide)
            .padding(DesignTokens.shelfPadding)
            .environment(CardActions())
            .environment(BoardEditor(
                model: model,
                create: { _, _ in 0 },
                rename: { _, _ in },
                recolor: { _, _ in },
                move: { _, _ in },
                delete: { _ in },
                addCards: { _, _ in },
                moveCards: { _, _ in }
            ))
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

#Preview("Link with page title") {
    CardPreview(card: CardSummary(
        id: 10,
        kind: .link,
        preview: "https://developer.apple.com/design/human-interface-guidelines/materials",
        metadata: #"{"pageTitle":"Materials","url":"https://developer.apple.com/design/human-interface-guidelines/materials"}"#,
        createdAt: .now
    ))
}

#Preview("Color") {
    CardPreview(card: CardSummary.previewCards[3])
}

#Preview("Unknown") {
    CardPreview(card: CardSummary.previewCards[4])
}
