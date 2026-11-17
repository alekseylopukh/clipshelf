import DesignSystem
import Foundation
import Store
import Testing
@testable import ShelfUI

@MainActor
final class BoardEditorTests {
    private struct Failure: Error {}

    private let suiteName = "BoardEditorTests-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let repository: CardRepository
    private let model: ShelfModel

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        repository = try CardRepository(database: AppDatabase.temporary())
        model = ShelfModel(
            defaults: defaults,
            observe: { _ in AsyncThrowingStream { $0.finish() } },
            observeBoards: { AsyncThrowingStream { $0.finish() } }
        )
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeEditor(create: BoardEditor.Create? = nil) -> BoardEditor {
        let repository = repository
        return BoardEditor(
            model: model,
            create: create ?? { try await repository.createBoard(named: $0, color: $1) },
            rename: { try await repository.renameBoard($0, to: $1) },
            recolor: { try await repository.recolorBoard($0, to: $1) },
            move: { try await repository.moveBoard($0, after: $1) },
            delete: { try await repository.deleteBoard($0) }
        )
    }

    private func makeBoards(_ colors: [BoardColor]) async throws -> [Board] {
        for (index, color) in colors.enumerated() {
            try await repository.createBoard(named: "Board \(index)", color: color.rawValue)
        }
        return try await refreshBoards()
    }

    @discardableResult
    private func refreshBoards() async throws -> [Board] {
        let boards = try await repository.boards()
        model.receiveBoards(boards)
        return boards
    }

    @Test func `new board becomes current tab`() async throws {
        let existing = try await makeBoards([.red])
        let editor = makeEditor()

        editor.beginNew()
        editor.name = "Recipes"
        await editor.save()

        #expect(editor.draft == nil)
        let created = try #require(try await repository.boards().last)
        #expect(created.name == "Recipes")
        #expect(model.tab == .board(id: created.id))
        model.receiveBoards(existing)
        #expect(model.tab == .board(id: created.id))
        try await refreshBoards()
        #expect(model.tab == .board(id: created.id))
        #expect(defaults.string(forKey: "ShelfTab") == "board:\(created.id)")
    }

    @Test func `new board takes the first unused color`() async throws {
        _ = try await makeBoards([.red, .yellow])
        let editor = makeEditor()

        editor.beginNew()

        #expect(editor.draft == BoardEditor.Draft(boardID: nil, name: "", color: .orange))
    }

    @Test func `new board cycles the palette once every color is used`() async throws {
        _ = try await makeBoards(BoardColor.allCases + [.blue])
        let editor = makeEditor()

        editor.beginNew()

        #expect(editor.color == .orange)
    }

    @Test func `cancel creates nothing`() async throws {
        let editor = makeEditor()

        editor.beginNew()
        editor.cancel()
        await editor.save()

        #expect(try await repository.boards().isEmpty)
        #expect(model.tab == .history)
    }

    @Test func `edit renames and recolors`() async throws {
        let board = try #require(try await makeBoards([.blue]).first)
        let editor = makeEditor()

        editor.beginEditing(board)
        #expect(editor.draft == BoardEditor.Draft(boardID: board.id, name: board.name, color: .blue))
        editor.name = " "
        editor.color = .green
        await editor.save()

        let edited = try #require(try await repository.boards().first)
        #expect(edited.name == "Untitled")
        #expect(edited.color == "green")
    }

    @Test func `edit current board needs a board tab`() async throws {
        let board = try #require(try await makeBoards([.purple]).first)
        let editor = makeEditor()

        editor.beginEditingCurrent()
        #expect(editor.draft == nil)

        model.showTab(.board(id: board.id))
        editor.beginEditingCurrent()
        #expect(editor.draft?.boardID == board.id)
    }

    @Test func `recolor from the menu`() async throws {
        let board = try #require(try await makeBoards([.gray]).first)

        await makeEditor().recolor(board, to: .red)

        #expect(try await repository.boards().first?.color == "red")
    }

    @Test func `delete asks first and leaves the tab`() async throws {
        let board = try #require(try await makeBoards([.blue, .red]).first)
        model.showTab(.board(id: board.id))
        let editor = makeEditor()
        var asked: [Int64] = []
        var confirms = false
        editor.confirmDeletion = { board in
            asked.append(board.id)
            return confirms
        }

        await editor.deleteCurrent()
        #expect(try await repository.boards().count == 2)

        confirms = true
        await editor.deleteCurrent()
        try await refreshBoards()

        #expect(asked == [board.id, board.id])
        #expect(try await repository.boards().map(\.id).contains(board.id) == false)
        #expect(model.tab == .history)
    }

    @Test(arguments: [
        (0, 2, [1, 2, 0]),
        (2, 0, [2, 0, 1]),
        (1, 0, [1, 0, 2]),
        (0, 1, [1, 0, 2]),
        (1, 1, [0, 1, 2])
    ])
    func `drop on a capsule moves the board there`(dragged: Int, target: Int, order: [Int]) async throws {
        let boards = try await makeBoards([.red, .orange, .yellow])

        await makeEditor().move(boards[dragged].id, onto: boards[target].id)

        #expect(try await repository.boards().map(\.id) == order.map { boards[$0].id })
    }

    @Test func `failure is reported and keeps the tab`() async {
        let editor = makeEditor { _, _ in throw Failure() }
        var titles: [String] = []
        editor.reportError = { error, title in
            #expect(error is Failure)
            titles.append(title)
        }

        editor.beginNew()
        await editor.save()

        #expect(titles.count == 1)
        #expect(model.tab == .history)
    }
}
