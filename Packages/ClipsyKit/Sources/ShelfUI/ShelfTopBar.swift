import AppKit
import DesignSystem
import Store
import SwiftUI

struct ShelfTopBar: View {
    let model: ShelfModel
    let commands: ShelfCommands

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: DesignTokens.spacingMedium) {
            HStack(spacing: DesignTokens.spacingMedium) {
                ShelfSearchField(model: model)
                ShelfFiltersButton(model: model)
                ScrollView(.horizontal) {
                    HStack(spacing: DesignTokens.spacingMedium) {
                        Button {
                            model.showTab(.history)
                        } label: {
                            Label("History", systemImage: "clock")
                        }
                        .buttonStyle(.glassTab(isSelected: model.tab == .history))
                        ForEach(model.boards) { board in
                            BoardCapsule(board: board, isSelected: model.tab == .board(id: board.id)) {
                                model.showTab(.board(id: board.id))
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                Button("New Board", systemImage: "plus") {
                    commands.newBoard?()
                }
                .buttonStyle(.glassIcon)
                .disabled(commands.newBoard == nil)
                ShelfMoreMenu(commands: commands)
            }
            .controlSize(.large)
        }
        .overlay(alignment: .bottomLeading) {
            Color.clear
                .frame(height: 0)
                .overlay(alignment: .topLeading) {
                    if model.isSearchFieldFocused, !model.suggestions.isEmpty {
                        SearchSuggestionList(model: model)
                            .padding(.top, DesignTokens.spacingSmall)
                    }
                }
        }
        .animation(reduceMotion ? nil : .default, value: model.tab)
    }
}

private struct ShelfFiltersButton: View {
    let model: ShelfModel

    var body: some View {
        @Bindable var model = model
        Button("Filters", systemImage: "line.3.horizontal.decrease") {
            model.isFilterBrowserPresented.toggle()
        }
        .buttonStyle(.glassIcon)
        .popover(isPresented: $model.isFilterBrowserPresented, arrowEdge: .top) {
            FilterBrowser(model: model)
        }
    }
}

private struct ShelfSearchField: View {
    let model: ShelfModel

    @FocusState private var isFocused: Bool
    @Environment(CardActions.self) private var actions

    var body: some View {
        @Bindable var model = model
        GlassSearchField {
            ForEach(model.tokens) { token in
                SearchTokenChip(token: token, model: model)
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
}

private struct BoardCapsule: View {
    let board: Board
    let isSelected: Bool
    let action: () -> Void

    @State private var isTargeted = false
    @Environment(BoardEditor.self) private var editor

    var body: some View {
        Button(action: action) {
            BoardLabel(board: board)
        }
        .buttonStyle(.glassTab(isSelected: isSelected || isTargeted))
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
