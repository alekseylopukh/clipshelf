import DesignSystem
import Observation
import os
import Store

@MainActor
@Observable
public final class BoardEditor {
    public typealias Create = @Sendable (String, String) async throws -> Int64
    public typealias Change = @Sendable (Int64, String) async throws -> Void
    public typealias Move = @Sendable (Int64, Int64?) async throws -> Void
    public typealias Delete = @Sendable (Int64) async throws -> Void
    public typealias AddCards = @Sendable ([Int64], Int64) async throws -> Void
    public typealias MoveCards = @Sendable ([Int64], Int64?) async throws -> Void

    struct Draft: Identifiable, Equatable {
        let boardID: Int64?
        var name: String
        var color: BoardColor
        var cardIDs: [Int64] = []

        var id: Int64 {
            boardID ?? 0
        }
    }

    var draft: Draft?

    @ObservationIgnored var confirmDeletion: (Board) async -> Bool = { _ in false }
    @ObservationIgnored var reportError: (any Error, String) async -> Void = { _, _ in }

    @ObservationIgnored private let model: ShelfModel
    @ObservationIgnored private let createBoard: Create
    @ObservationIgnored private let renameBoard: Change
    @ObservationIgnored private let recolorBoard: Change
    @ObservationIgnored private let moveBoard: Move
    @ObservationIgnored private let deleteBoard: Delete
    @ObservationIgnored private let addCards: AddCards
    @ObservationIgnored private let moveCards: MoveCards

    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Boards")

    public init(
        model: ShelfModel,
        create: @escaping Create,
        rename: @escaping Change,
        recolor: @escaping Change,
        move: @escaping Move,
        delete: @escaping Delete,
        addCards: @escaping AddCards,
        moveCards: @escaping MoveCards
    ) {
        self.model = model
        createBoard = create
        renameBoard = rename
        recolorBoard = recolor
        moveBoard = move
        deleteBoard = delete
        self.addCards = addCards
        self.moveCards = moveCards
    }

    var name: String {
        get { draft?.name ?? "" }
        set { draft?.name = newValue }
    }

    var color: BoardColor {
        get { draft?.color ?? .gray }
        set { draft?.color = newValue }
    }

    func beginNew() {
        let used = Set(model.boards.map(\.color))
        let palette = BoardColor.allCases
        let color = palette.first { !used.contains($0.rawValue) } ?? palette[model.boards.count % palette.count]
        draft = Draft(boardID: nil, name: "", color: color)
    }

    func beginEditing(_ board: Board) {
        draft = Draft(boardID: board.id, name: board.name, color: BoardColor(rawValue: board.color) ?? .gray)
    }

    func beginEditingCurrent() {
        guard let board = currentBoard else { return }
        beginEditing(board)
    }

    func cancel() {
        draft = nil
    }

    func save() async {
        guard let draft else { return }
        self.draft = nil
        guard let boardID = draft.boardID else {
            var createdID: Int64?
            await perform(String(
                localized: "Clipsy can’t create this board.",
                comment: "Title of the alert shown when creating a board fails"
            )) {
                createdID = try await createBoard(draft.name, draft.color.rawValue)
            }
            guard let createdID else { return }
            if draft.cardIDs.isEmpty {
                model.showTab(.board(id: createdID))
            } else {
                await add(draft.cardIDs, to: createdID)
            }
            return
        }
        guard let board = model.boards.first(where: { $0.id == boardID }) else { return }
        await perform(String(
            localized: "Clipsy can’t change this board.",
            comment: "Title of the alert shown when renaming or recoloring a board fails"
        )) {
            if draft.name != board.name {
                try await renameBoard(boardID, draft.name)
            }
            if draft.color.rawValue != board.color {
                try await recolorBoard(boardID, draft.color.rawValue)
            }
        }
    }

    func recolor(_ board: Board, to color: BoardColor) async {
        guard color.rawValue != board.color else { return }
        await perform(String(
            localized: "Clipsy can’t change this board.",
            comment: "Title of the alert shown when renaming or recoloring a board fails"
        )) {
            try await recolorBoard(board.id, color.rawValue)
        }
    }

    /// drops before the target when moving left and after it when moving right
    func move(_ boardID: Int64, onto targetID: Int64) async {
        let ids = model.boards.map(\.id)
        guard boardID != targetID,
              let from = ids.firstIndex(of: boardID),
              let to = ids.firstIndex(of: targetID)
        else { return }
        let previousID = from < to ? targetID : (to > 0 ? ids[to - 1] : nil)
        await perform(String(
            localized: "Clipsy can’t move this board.",
            comment: "Title of the alert shown when reordering boards fails"
        )) {
            try await moveBoard(boardID, previousID)
        }
    }

    func delete(_ board: Board) async {
        guard await confirmDeletion(board) else { return }
        await perform(String(
            localized: "Clipsy can’t delete this board.",
            comment: "Title of the alert shown when deleting a board fails"
        )) {
            try await deleteBoard(board.id)
        }
    }

    func deleteCurrent() async {
        guard let board = currentBoard else { return }
        await delete(board)
    }

    func boards(forAdding cards: [CardSummary]) -> [Board] {
        model.boards.filter { board in !cards.allSatisfy { $0.boardID == board.id } }
    }

    func beginNew(adding cardIDs: [Int64]) {
        beginNew()
        draft?.cardIDs = cardIDs
    }

    func add(_ cardIDs: [Int64], to boardID: Int64) async {
        guard !cardIDs.isEmpty else { return }
        await perform(String(
            localized: "Clipsy can’t add these cards to the board.",
            comment: "Title of the alert shown when adding cards to a board fails"
        )) {
            try await addCards(cardIDs, boardID)
        }
    }

    func drop(_ items: [TabDropItem], onBoard boardID: Int64) async {
        var cardIDs: [Int64] = []
        for item in items {
            switch item {
            case let .board(reference):
                await move(reference.boardID, onto: boardID)
                return
            case let .card(reference):
                cardIDs.append(reference.cardID)
            }
        }
        let ids = draggedCards(cardIDs).filter { id in
            model.cards.first { $0.id == id }?.boardID != boardID
        }
        await add(ids, to: boardID)
    }

    func reorder(_ cardIDs: [Int64], onto targetID: Int64) async {
        let ids = model.cards.map(\.id)
        let moving = draggedCards(cardIDs).filter(ids.contains)
        guard case .board = model.tab, !model.isSearching,
              !moving.contains(targetID),
              let first = moving.first.flatMap(ids.firstIndex(of:)),
              let target = ids.firstIndex(of: targetID)
        else { return }
        let rest = ids.filter { !moving.contains($0) }
        guard let targetInRest = rest.firstIndex(of: targetID) else { return }
        let previousID = first < target ? targetID : (targetInRest > 0 ? rest[targetInRest - 1] : nil)
        await move(moving, after: previousID)
    }

    func moveSelection(_ direction: ShelfModel.Direction) async {
        let ids = model.cards.map(\.id)
        let moving = model.selectedCards.map(\.id)
        guard case .board = model.tab, !model.isSearching,
              let first = moving.first.flatMap(ids.firstIndex(of:)),
              let last = moving.last.flatMap(ids.firstIndex(of:))
        else { return }
        let rest = ids.filter { !moving.contains($0) }
        let previousID: Int64?
        switch direction {
        case .previous:
            guard first > 0, let before = rest.firstIndex(of: ids[first - 1]) else { return }
            previousID = before > 0 ? rest[before - 1] : nil
        case .next:
            guard last + 1 < ids.count else { return }
            previousID = ids[last + 1]
        }
        await move(moving, after: previousID)
    }

    private var currentBoard: Board? {
        guard case let .board(id) = model.tab else { return nil }
        return model.boards.first { $0.id == id }
    }

    private func draggedCards(_ cardIDs: [Int64]) -> [Int64] {
        let selected = model.selectedCards.map(\.id)
        return cardIDs.contains(where: selected.contains) ? selected : cardIDs
    }

    private func move(_ cardIDs: [Int64], after previousID: Int64?) async {
        await perform(String(
            localized: "Clipsy can’t move these cards.",
            comment: "Title of the alert shown when reordering cards on a board fails"
        )) {
            try await moveCards(cardIDs, previousID)
        }
    }

    private func perform(_ failureTitle: String, _ work: () async throws -> Void) async {
        do {
            try await work()
        } catch {
            Self.logger.error("board change failed: \(String(describing: type(of: error)), privacy: .public)")
            await reportError(error, failureTitle)
        }
    }
}
