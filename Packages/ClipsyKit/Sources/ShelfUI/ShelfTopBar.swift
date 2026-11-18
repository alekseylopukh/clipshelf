import AppKit
import DesignSystem
import Store
import SwiftUI

struct ShelfTopBar: View {
    let model: ShelfModel
    let commands: ShelfCommands

    @State private var leadingWidth: CGFloat?
    @State private var trackWidth: CGFloat?
    @State private var searchFieldWidth = DesignTokens.searchFieldWidth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: DesignTokens.spacingMedium) {
            HStack(spacing: DesignTokens.spacingMedium) {
                HStack(spacing: DesignTokens.spacingMedium) {
                    ShelfSearchField(model: model)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { searchFieldWidth = $0 }
                    ShelfFiltersButton(model: model)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { leadingWidth = $0 }
                Spacer(minLength: DesignTokens.spacingMedium)
                ScrollView(.horizontal) {
                    ShelfTabTrack(model: model)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .mask {
                    Rectangle().padding(.vertical, -DesignTokens.spacingMedium)
                }
                .frame(maxWidth: trackWidth)
                .layoutPriority(1)
                Button("New Board", systemImage: "plus") {
                    commands.newBoard?()
                }
                .buttonStyle(.glassIcon)
                .disabled(commands.newBoard == nil)
                Spacer(minLength: DesignTokens.spacingMedium)
                HStack(spacing: DesignTokens.spacingMedium) {
                    if let count = model.selectedCount {
                        ShelfSelectionCount(count: count)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .scale(scale: DesignTokens.searchTokenEntranceScale, anchor: .trailing)
                                    .combined(with: .opacity)
                            )
                    }
                    ShelfMoreMenu(commands: commands)
                }
                .frame(minWidth: leadingWidth, alignment: .trailing)
                .animation(
                    reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.pop,
                    value: model.selectedCount
                )
            }
            .controlSize(.large)
            .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.standard, value: model.tokens)
        }
        .overlay(alignment: .bottomLeading) {
            Color.clear
                .frame(height: .zero)
                .overlay(alignment: .topLeading) {
                    if model.isSearchFieldFocused, !model.suggestions.isEmpty {
                        SearchSuggestionList(model: model, width: searchFieldWidth)
                            .padding(.top, DesignTokens.spacingSmall)
                            .transition(suggestionTransition)
                    }
                }
                .animation(
                    reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.present,
                    value: model.isSearchFieldFocused && !model.suggestions.isEmpty
                )
        }
    }

    private var suggestionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity.animation(DesignTokens.Motion.reduced) }
        let transition = AnyTransition.scale(scale: DesignTokens.searchSuggestionEntranceScale, anchor: .top)
            .combined(with: .offset(y: DesignTokens.searchSuggestionEntranceOffset))
            .combined(with: .opacity)
        return .asymmetric(
            insertion: transition.animation(DesignTokens.Motion.present),
            removal: transition.animation(DesignTokens.Motion.quick)
        )
    }
}

private struct ShelfTabTrack: View {
    let model: ShelfModel

    var body: some View {
        TabTrack(selection: model.tab, label: Text("Boards")) { namespace in
            Button {
                model.showTab(.history)
            } label: {
                Label("History", systemImage: "clock")
            }
            .buttonStyle(.plain)
            .tabTrackSegment(id: CardList.history, in: namespace, isSelected: model.tab == .history)
            ForEach(model.boards) { board in
                BoardTab(board: board, namespace: namespace, isSelected: model.tab == .board(id: board.id)) {
                    model.showTab(.board(id: board.id))
                }
            }
        }
    }
}

private struct ShelfSelectionCount: View {
    let count: Int

    var body: some View {
        Text("\(count) selected")
            .font(.body)
            .monospacedDigit()
            .contentTransition(.numericText())
            .padding(.horizontal, DesignTokens.spacingLarge)
            .frame(height: DesignTokens.topBarControlHeight)
            .glassEffect(.regular, in: .capsule)
    }
}

private struct ShelfFiltersButton: View {
    let model: ShelfModel

    var body: some View {
        @Bindable var model = model
        Button("Filters", systemImage: "line.3.horizontal.decrease") {
            model.isFilterBrowserPresented.toggle()
        }
        .buttonStyle(.glassIcon(isProminent: !model.tokens.isEmpty))
        .popover(isPresented: $model.isFilterBrowserPresented, arrowEdge: .top) {
            FilterBrowser(model: model)
        }
    }
}

private struct ShelfSearchField: View {
    let model: ShelfModel

    @FocusState private var isFocused: Bool
    @Environment(CardActions.self) private var actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        GlassSearchField {
            ForEach(model.tokens) { token in
                SearchTokenChip(token: token, model: model)
                    .transition(tokenTransition)
            }
            TextField("Search", text: $model.query, selection: $model.searchSelection)
                .textFieldStyle(.plain)
                .frame(minWidth: DesignTokens.searchTextMinimumWidth)
                .focused($isFocused)
                .onKeyPress(.escape) {
                    model.cancelSearchField() ? .handled : .ignored
                }
                .onKeyPress(.delete) {
                    model.removeLastToken() ? .handled : .ignored
                }
                .onKeyPress(keys: [.downArrow, .upArrow]) { press in
                    let direction: ShelfModel.Direction = press.key == .downArrow ? .next : .previous
                    return model.handleSearchFieldArrow(direction, modifiers: press.modifiers) ? .handled : .ignored
                }
                .onKeyPress(keys: [.tab]) { press in
                    guard press.modifiers.isEmpty else { return .ignored }
                    model.focusCards()
                    return .handled
                }
                .onKeyPress(.return) {
                    if !model.acceptHighlightedSuggestion() {
                        actions.pasteOnDoubleClick(model.selectedCards.map(\.id))
                    }
                    return .handled
                }
                .onChange(of: model.isSearchFieldFocused) { _, isFocused in
                    self.isFocused = isFocused
                }
                .onChange(of: isFocused) { _, isFocused in
                    model.searchFieldFocusDidChange(isFocused)
                }
            if !model.query.isEmpty || !model.tokens.isEmpty {
                Button("Clear Search", systemImage: "xmark.circle.fill") {
                    _ = model.clearSearch()
                }
                .buttonStyle(.accessoryIcon)
            }
        }
    }

    private var tokenTransition: AnyTransition {
        guard !reduceMotion else { return .opacity.animation(DesignTokens.Motion.reduced) }
        return AnyTransition.scale(scale: DesignTokens.searchTokenEntranceScale, anchor: .leading)
            .combined(with: .opacity)
            .animation(DesignTokens.Motion.pop)
    }
}

private struct BoardTab: View {
    let board: Board
    let namespace: Namespace.ID
    let isSelected: Bool
    let action: () -> Void

    @State private var isTargeted = false
    @Environment(BoardEditor.self) private var editor

    var body: some View {
        Button(action: action) {
            BoardLabel(board: board)
        }
        .buttonStyle(.plain)
        .tabTrackSegment(
            id: CardList.board(id: board.id),
            in: namespace,
            isSelected: isSelected,
            isTargeted: isTargeted
        )
        .contextMenu {
            BoardContextMenu(board: board)
        }
        .draggable(BoardReference(boardID: board.id)) {
            BoardLabel(board: board)
        }
        .dropDestination(for: TabDropItem.self) { items, _ in
            Task {
                await editor.drop(items, onBoard: board.id)
            }
            return !items.isEmpty
        } isTargeted: {
            isTargeted = $0
        }
    }
}

private struct BoardLabel: View {
    let board: Board

    var body: some View {
        Label {
            Text(board.name)
        } icon: {
            BoardDot(BoardColor(rawValue: board.color) ?? .gray)
        }
        .lineLimit(1)
    }
}

/// a glass button that pops up an `NSMenu`, because macOS menus ignore `.buttonStyle(.glass)`
private struct ShelfMoreMenu: View {
    let commands: ShelfCommands

    @State private var anchor = PopUpMenuAnchor()

    var body: some View {
        Button("More", systemImage: "ellipsis") {
            anchor.popUp(menu())
        }
        .buttonStyle(.glassIcon)
        .popUpMenuAnchor(anchor)
    }

    private func menu() -> NSMenu {
        let commands = commands
        let menu = NSMenu()
        menu.autoenablesItems = false
        let newTextCard = ActionMenuItem(String(localized: "New Text Card"), systemImage: "square.and.pencil") {
            commands.newTextCard?()
        }
        newTextCard.isEnabled = commands.newTextCard != nil
        menu.addItem(newTextCard)
        let startSequence = ActionMenuItem(String(localized: "Start Sequence"), systemImage: "list.number") {
            commands.startSequence?()
        }
        startSequence.isEnabled = commands.startSequence != nil
        menu.addItem(startSequence)
        menu.addItem(.separator())
        if commands.isCapturePaused() {
            menu.addItem(ActionMenuItem(String(localized: "Resume Capture"), systemImage: "play.circle") {
                commands.setCapturePaused?(false)
            })
        } else {
            menu.addItem(ActionMenuItem(String(localized: "Pause Capture"), systemImage: "pause.circle") {
                commands.setCapturePaused?(true)
            })
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(String(localized: "Settings…")) {
            commands.openSettings?()
        })
        return menu
    }
}

private struct SearchTokenChip: View {
    let token: SearchToken
    let model: ShelfModel

    var body: some View {
        let title = model.title(of: token)
        Button {
            model.removeToken(token)
        } label: {
            SearchTokenLabel(token: token, title: title, boards: model.boards)
        }
        .buttonStyle(.removableChip)
        .accessibilityLabel(Text(
            "Remove Filter \(title)",
            comment: "VoiceOver label of a search filter token; the argument is the filter"
        ))
        .help(Text("Remove Filter", comment: "Tooltip of a search filter token"))
    }
}
