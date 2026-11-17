import Store

@MainActor
public final class CardDeletion {
    public typealias Delete = @Sendable ([Int64], CardList) async throws -> DeletedCards
    public typealias Restore = @Sendable (DeletedCards) async throws -> [Int64]

    private let deleteCards: Delete
    private let restoreCards: Restore
    private var undoStack: [DeletedCards] = []
    private var isBusy = false
    private var generation = 0

    public init(delete: @escaping Delete, restore: @escaping Restore) {
        deleteCards = delete
        restoreCards = restore
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func delete(_ ids: [Int64], in list: CardList, confirm: (Int) async -> Bool) async throws -> Bool {
        guard !ids.isEmpty, !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        if ids.count > 1, await confirm(ids.count) == false {
            return false
        }
        let started = generation
        let deleted = try await deleteCards(ids, list)
        if generation == started {
            undoStack.append(deleted)
        }
        return true
    }

    func undo() async throws {
        guard !isBusy, let last = undoStack.popLast() else { return }
        isBusy = true
        defer { isBusy = false }
        let started = generation
        do {
            _ = try await restoreCards(last)
        } catch {
            if generation == started {
                undoStack.append(last)
            }
            throw error
        }
    }

    func discardUndo() {
        undoStack.removeAll()
        generation += 1
    }
}
