import Foundation
import Synchronization

/// a clock that only moves when `advance(by:)` is called; `sleeps` yields each time a sleeper starts waiting
final class TestClock: Clock {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var sleepers: [UUID: Sleeper] = [:]
        var cancelled: Set<UUID> = []
    }

    let sleeps: AsyncStream<Void>
    private let sleepsContinuation: AsyncStream<Void>.Continuation
    private let state = Mutex(State())

    init() {
        (sleeps, sleepsContinuation) = AsyncStream.makeStream()
    }

    var now: Instant {
        state.withLock { $0.now }
    }

    var minimumResolution: Duration {
        .zero
    }

    func sleep(until deadline: Instant, tolerance _: Duration?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let isCancelled = state.withLock { state in
                    guard state.cancelled.remove(id) == nil else { return true }
                    state.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return false
                }
                if isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    sleepsContinuation.yield()
                }
            }
        } onCancel: {
            let sleeper = state.withLock { state in
                let sleeper = state.sleepers.removeValue(forKey: id)
                if sleeper == nil {
                    state.cancelled.insert(id)
                }
                return sleeper
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    func advance(by duration: Duration) {
        let due = state.withLock { state in
            state.now = state.now.advanced(by: duration)
            let now = state.now
            let due = state.sleepers.filter { $0.value.deadline <= now }
            for id in due.keys {
                state.sleepers[id] = nil
            }
            return due.values.map(\.continuation)
        }
        for continuation in due {
            continuation.resume()
        }
    }
}
