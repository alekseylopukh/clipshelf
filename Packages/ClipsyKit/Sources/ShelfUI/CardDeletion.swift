import Store

@MainActor
public final class CardDeletion {
    public typealias Delete = @Sendable ([Int64], CardList) async throws -> DeletedCards
    public typealias Restore = @Sendable (DeletedCards) async throws -> [Int64]

    private let deleteCards: Delete
    private let restoreCards: Restore
    private var undoStack: [[DeletedCards]] = []
    private var isBusy = false
    private var generation = 0

    public init(delete: @escaping Delete, restore: @escaping Restore) {
        deleteCards = delete
        restoreCards = restore
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func delete(_ idsByList: [CardList: [Int64]], confirm: (Int) async -> Bool) async throws -> Bool {
        let count = idsByList.values.reduce(0) { $0 + $1.count }
        guard count > 0, !isBusy else { return false }
        isBusy = true
        defer { isBusy = false }
        if count > 1, await confirm(count) == false {
            return false
        }
        let started = generation
        var deleted: [DeletedCards] = []
        defer {
            if generation == started, !deleted.isEmpty {
                undoStack.append(deleted)
            }
        }
        for (list, ids) in idsByList where !ids.isEmpty {
            try await deleted.append(deleteCards(ids, list))
        }
        return true
    }

    func undo() async throws {
        guard !isBusy, var last = undoStack.popLast() else { return }
        isBusy = true
        defer { isBusy = false }
        let started = generation
        while let deleted = last.last {
            do {
                _ = try await restoreCards(deleted)
            } catch {
                if generation == started {
                    undoStack.append(last)
                }
                throw error
            }
            last.removeLast()
        }
    }

    func discardUndo() {
        undoStack.removeAll()
        generation += 1
    }
}
