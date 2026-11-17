import AppKit
import os
import Store

@MainActor
public final class PasteboardMonitor {
    public static let pollInterval = Duration.milliseconds(500)
    public static let pollTolerance = Duration.milliseconds(100)

    public let capturedCardIDs: AsyncStream<Int64>

    private let pasteboard: any PasteboardReading
    private let frontmostApp: any FrontmostAppProviding
    private let clock: any Clock<Duration>
    private let changeCountStore: any ChangeCountStoring
    private let isOwnWrite: (Int) -> Bool
    private let policy: () -> CapturePolicy
    private let repository: CardRepository
    private let continuation: AsyncStream<Int64>.Continuation
    private let logger = Logger(subsystem: "app.gonar.clipsy", category: "Capture")
    private var pendingChangeCount: Int?

    public init(
        pasteboard: any PasteboardReading = NSPasteboard.general,
        frontmostApp: any FrontmostAppProviding = NSWorkspace.shared,
        clock: any Clock<Duration> = ContinuousClock(),
        changeCountStore: any ChangeCountStoring = UserDefaults.standard,
        isOwnWrite: @escaping (Int) -> Bool,
        policy: @escaping () -> CapturePolicy,
        repository: CardRepository
    ) {
        self.pasteboard = pasteboard
        self.frontmostApp = frontmostApp
        self.clock = clock
        self.changeCountStore = changeCountStore
        self.isOwnWrite = isOwnWrite
        self.policy = policy
        self.repository = repository
        (capturedCardIDs, continuation) = AsyncStream.makeStream()
    }

    deinit {
        continuation.finish()
    }

    /// polls until the calling task is cancelled, then throws `CancellationError`
    public func run() async throws {
        while true {
            await poll()
            try await clock.sleep(for: Self.pollInterval, tolerance: Self.pollTolerance)
        }
    }

    func poll() async {
        let changeCount = pasteboard.changeCount
        guard changeCount != changeCountStore.lastHandledChangeCount else {
            pendingChangeCount = nil
            return
        }
        guard changeCount == pendingChangeCount else {
            pendingChangeCount = changeCount
            return
        }
        pendingChangeCount = nil
        changeCountStore.lastHandledChangeCount = changeCount

        let sourceApp = frontmostApp.frontmostApp
        let policy = policy()
        if let reason = policy.skipReason(
            types: pasteboard.items.flatMap(\.types),
            frontmostBundleID: sourceApp?.bundleID,
            isOwnWriteChangeCount: isOwnWrite(changeCount)
        ) {
            logger.debug("skipped change: \(String(describing: reason), privacy: .public)")
            return
        }
        // a write between the type check and this read is handled on a later poll
        guard let sourceApp,
              let snapshot = PasteboardSnapshot(pasteboard: pasteboard),
              pasteboard.changeCount == changeCount else { return }

        if let reason = await Self.secretSkipReason(for: snapshot, policy: policy) {
            logger.debug("skipped change: \(String(describing: reason), privacy: .public)")
            return
        }
        let card = await Self.makeCard(from: snapshot, sourceApp: sourceApp)
        do {
            let id = try await repository.record(card)
            continuation.yield(id)
        } catch {
            logger.error("recording a card failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// records content dropped on a Clipsy window and reports it on `capturedCardIDs`; the drop is an explicit
    /// action, so the capture policy does not apply. The pasteboard is read before the first suspension
    public func recordDrop(from pasteboard: some PasteboardReading) async throws {
        guard let sourceApp = frontmostApp.frontmostApp,
              let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        else {
            return
        }
        let card = await Self.makeCard(from: snapshot, sourceApp: sourceApp)
        let id = try await repository.record(card)
        continuation.yield(id)
    }

    @concurrent
    private nonisolated static func secretSkipReason(
        for snapshot: PasteboardSnapshot,
        policy: CapturePolicy
    ) async -> SkipReason? {
        policy.secretSkipReason(for: snapshot)
    }

    @concurrent
    private nonisolated static func makeCard(from snapshot: PasteboardSnapshot, sourceApp: SourceApp) async -> NewCard {
        NewCard(snapshot: snapshot, sourceApp: sourceApp)
    }
}
