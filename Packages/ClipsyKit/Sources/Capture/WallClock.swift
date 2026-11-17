import Foundation

public protocol WallClock: Sendable {
    var now: Date { get }
    func sleep(until date: Date) async throws
}

public struct SystemWallClock: WallClock {
    public init() {}

    public var now: Date {
        Date()
    }

    public func sleep(until date: Date) async throws {
        try await Task.sleep(for: .seconds(max(0, date.timeIntervalSinceNow)))
    }
}
