import AppKit
import Store
import Testing
@testable import Capture

@MainActor
private final class FakeFrontmostApp: FrontmostAppProviding {
    var frontmostApp: SourceApp? = SourceApp(bundleID: "com.example.editor", name: "Editor")
}

@MainActor
private final class FakeChangeCountStore: ChangeCountStoring {
    var lastHandledChangeCount: Int?
}

@MainActor
struct PasteboardMonitorTests {
    private let pasteboard = NSPasteboard.withUniqueName()
    private let frontmostApp = FakeFrontmostApp()
    private let changeCountStore = FakeChangeCountStore()
    private let repository: CardRepository

    init() throws {
        repository = try CardRepository(database: AppDatabase.temporary())
    }

    private func makeMonitor(
        policy: @escaping () -> CapturePolicy = { CapturePolicy() },
        isOwnWrite: @escaping (Int) -> Bool = { _ in false }
    ) -> PasteboardMonitor {
        PasteboardMonitor(
            pasteboard: pasteboard,
            frontmostApp: frontmostApp,
            clock: ContinuousClock(),
            changeCountStore: changeCountStore,
            isOwnWrite: isOwnWrite,
            policy: policy,
            repository: repository
        )
    }

    private func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func history() async throws -> [CardSummary] {
        try await repository.cards(in: .history)
    }

    @Test func `change produces one card`() async throws {
        defer { pasteboard.releaseGlobally() }
        let monitor = makeMonitor()
        copy("hello")

        await monitor.poll()
        #expect(try await history().isEmpty)
        await monitor.poll()
        await monitor.poll()

        let cards = try await history()
        #expect(cards.map(\.preview) == ["hello"])
        var ids = monitor.capturedCardIDs.makeAsyncIterator()
        #expect(await ids.next() == cards.first?.id)
    }

    @Test func `multi step write coalesces`() async throws {
        defer { pasteboard.releaseGlobally() }
        let monitor = makeMonitor()

        copy("partial")
        await monitor.poll()
        copy("full")
        await monitor.poll()
        await monitor.poll()
        pasteboard.clearContents()
        await monitor.poll()
        pasteboard.setString("written after clearing", forType: .string)
        await monitor.poll()
        await monitor.poll()

        let previews = try await history().map(\.preview)
        #expect(previews == ["written after clearing", "full"])
    }

    @Test func `own write is ignored`() async throws {
        defer { pasteboard.releaseGlobally() }
        copy("ours")
        let ownChangeCount = pasteboard.changeCount
        let monitor = makeMonitor(isOwnWrite: { $0 == ownChangeCount })

        await monitor.poll()
        await monitor.poll()
        copy("marked")
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType(PasteboardMarker.ownWrite))
        await monitor.poll()
        await monitor.poll()

        #expect(try await history().isEmpty)
    }

    @Test func `relaunch does not recapture`() async throws {
        defer { pasteboard.releaseGlobally() }
        copy("first")
        let firstRun = makeMonitor()
        await firstRun.poll()
        await firstRun.poll()
        let firstID = try #require(try await history().first?.id)

        let secondRun = makeMonitor()
        await secondRun.poll()
        await secondRun.poll()
        copy("second")
        await secondRun.poll()
        await secondRun.poll()

        var ids = secondRun.capturedCardIDs.makeAsyncIterator()
        let nextID = try #require(await ids.next())
        #expect(nextID != firstID)
        #expect(try await history().count == 2)
    }

    @Test func `paused produces nothing`() async throws {
        defer { pasteboard.releaseGlobally() }
        var policy = CapturePolicy(isPaused: true)
        let monitor = makeMonitor(policy: { policy })
        copy("while paused")

        await monitor.poll()
        await monitor.poll()
        policy.isPaused = false
        await monitor.poll()
        await monitor.poll()
        #expect(try await history().isEmpty)

        copy("after resume")
        await monitor.poll()
        await monitor.poll()
        #expect(try await history().map(\.preview) == ["after resume"])
    }

    @Test func `no frontmost app produces nothing`() async throws {
        defer { pasteboard.releaseGlobally() }
        frontmostApp.frontmostApp = nil
        let monitor = makeMonitor()
        copy("hello")

        await monitor.poll()
        await monitor.poll()

        #expect(try await history().isEmpty)
    }
}
