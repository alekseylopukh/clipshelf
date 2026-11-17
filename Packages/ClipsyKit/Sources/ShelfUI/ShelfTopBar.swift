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
                Button("New Board", systemImage: "plus") {
                    commands.newBoard?()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .disabled(commands.newBoard == nil)
                ShelfMoreMenu(commands: commands)
            }
            .controlSize(.large)
        }
        .animation(reduceMotion ? nil : .default, value: model.tab)
    }
}

private struct ShelfSearchField: View {
    let model: ShelfModel

    var body: some View {
        @Bindable var model = model
        HStack(spacing: DesignTokens.spacingSmall) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search", text: $model.query)
                .textFieldStyle(.plain)
                .onKeyPress(.escape) {
                    model.clearSearch() ? .handled : .ignored
                }
            if !model.query.isEmpty {
                Button("Clear Search", systemImage: "xmark.circle.fill") {
                    model.query = ""
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DesignTokens.spacingLarge)
        .padding(.vertical, DesignTokens.spacingMedium)
        .frame(width: DesignTokens.searchFieldWidth)
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

    @Environment(BoardEditor.self) private var editor

    var body: some View {
        TabCapsule(isSelected: isSelected, action: action) {
            BoardLabel(board: board)
        }
        .contextMenu {
            BoardContextMenu(board: board)
        }
        .draggable(BoardReference(boardID: board.id)) {
            BoardLabel(board: board)
        }
        .dropDestination(for: BoardReference.self) { references, _ in
            guard let reference = references.first, reference.boardID != board.id else { return false }
            Task {
                await editor.move(reference.boardID, onto: board.id)
            }
            return true
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
            Label("More", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.glass)
        .fixedSize()
    }
}
