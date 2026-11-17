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
                        TabCapsule(isSelected: model.tab == .history) {
                            model.showTab(.history)
                        } label: {
                            Label("History", systemImage: "clock")
                        }
                        ForEach(model.boards) { board in
                            BoardCapsule(board: board, isSelected: model.tab == .board(id: board.id)) {
                                model.showTab(.board(id: board.id))
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                Button {
                    commands.newBoard?()
                } label: {
                    TopBarIcon(title: "New Board", systemImage: "plus")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
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
        Button {
            model.isFilterBrowserPresented.toggle()
        } label: {
            TopBarIcon(title: "Filters", systemImage: "line.3.horizontal.decrease")
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
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
        HStack(spacing: DesignTokens.spacingSmall) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
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
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DesignTokens.spacingLarge)
        .frame(minWidth: DesignTokens.searchFieldWidth, minHeight: DesignTokens.topBarControlHeight)
        .fixedSize(horizontal: true, vertical: false)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

private struct TabCapsule<Title: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Title

    var body: some View {
        if isSelected {
            Button(action: action, label: label)
                .buttonStyle(.glassProminent)
                .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: action, label: label)
                .buttonStyle(.glass)
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
        TabCapsule(isSelected: isSelected || isTargeted, action: action) {
            BoardLabel(board: board)
        }
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
            Circle()
                .fill((BoardColor(rawValue: board.color) ?? .gray).color)
                .frame(width: DesignTokens.boardDotSize, height: DesignTokens.boardDotSize)
        }
        .lineLimit(1)
    }
}

private struct ShelfMoreMenu: View {
    let commands: ShelfCommands

    var body: some View {
        Menu {
            Button("New Text Card", systemImage: "square.and.pencil") {
                commands.newTextCard?()
            }
            .disabled(commands.newTextCard == nil)
            Button("Start Sequence", systemImage: "list.number") {
                commands.startSequence?()
            }
            .disabled(commands.startSequence == nil)
            Divider()
            if commands.isCapturePaused() {
                Button("Resume Capture", systemImage: "play.circle") {
                    commands.setCapturePaused?(false)
                }
            } else {
                Button("Pause Capture", systemImage: "pause.circle") {
                    commands.setCapturePaused?(true)
                }
            }
            Divider()
            Button("Settings…") {
                commands.openSettings?()
            }
        } label: {
            TopBarIcon(title: "More", systemImage: "ellipsis")
        }
        .menuIndicator(.hidden)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .fixedSize()
    }
}

/// a fixed glyph box keeps icon-only glass buttons as tall as the text capsules
private struct TopBarIcon: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: DesignTokens.topBarIconSize, height: DesignTokens.topBarIconSize)
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
            HStack(spacing: DesignTokens.spacingSmall) {
                SearchTokenLabel(token: token, title: title, boards: model.boards)
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(DesignTokens.searchTokenInsets)
            .background(.fill.secondary, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(
            "Remove Filter \(title)",
            comment: "VoiceOver label of a search filter token; the argument is the filter"
        ))
        .help(Text("Remove Filter", comment: "Tooltip of a search filter token"))
    }
}
