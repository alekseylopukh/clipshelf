import AppKit
import Store
import Testing
@testable import Pasting

@MainActor
final class SequenceCoordinatorTests {
    private final class EventLog {
        var events: [String] = []
    }

    private struct FakeTrust: AccessibilityTrust {
        var isTrusted: Bool

        func requestTrust() -> Bool {
            false
        }
    }

    private struct FakeKeystroke: PasteKeystrokePosting {
        let log: EventLog

        func postCommandV() {
            log.events.append("⌘V")
        }

        func postCommandC() {
            log.events.append("⌘C")
        }
    }

    private struct FakeSoundPlayer: SoundPlaying {
        func play(_: SoundEffect) {}
    }

    private nonisolated static func text(of cardID: Int64) -> [Representation] {
        [Representation(
            itemIndex: 0,
            uti: NSPasteboard.PasteboardType.string.rawValue,
            data: Data("card \(cardID)".utf8)
        )]
    }

    private let suiteName = "SequenceCoordinatorTests-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let pasteboard = NSPasteboard.withUniqueName()
    private let log = EventLog()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    isolated deinit {
        pasteboard.releaseGlobally()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeCoordinator(trusted: Bool = true) -> SequenceCoordinator {
        let writer = PasteboardWriter(pasteboard: pasteboard)
        let keystroke = FakeKeystroke(log: log)
        return SequenceCoordinator(
            sequence: PasteSequence(defaults: defaults),
            detector: SequencePasteDetector(mechanism: .dataProvider, writer: writer, settleDelay: .zero),
            paster: PasteCoordinator(
                writer: writer,
                representations: { Self.text(of: $0) },
                trust: FakeTrust(isTrusted: trusted),
                keystroke: keystroke,
                sound: FakeSoundPlayer(),
                defaults: defaults
            ),
            representations: { Self.text(of: $0) },
            loadCards: { ids in ids.sorted().map { CardSummary(id: $0, kind: .text, createdAt: .now) } },
            trust: FakeTrust(isTrusted: trusted),
            keystroke: keystroke,
            frontmostTarget: { nil }
        )
    }

    private var pastedText: String? {
        pasteboard.string(forType: .string)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0 ..< 500 where condition() == false {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    @Test func `captures join open sequence`() {
        let coordinator = makeCoordinator()

        coordinator.didCapture(1)
        #expect(coordinator.sequence.entries.isEmpty)

        coordinator.start(shelfSelection: nil)
        coordinator.didCapture(2)
        coordinator.didCapture(3)
        coordinator.didCapture(2)

        #expect(coordinator.sequence.entries.map(\.cardID) == [2, 3, 2])
    }

    @Test(arguments: [true, false])
    func `start outside the shelf copies the selection only with Accessibility`(trusted: Bool) {
        let coordinator = makeCoordinator(trusted: trusted)

        coordinator.start(shelfSelection: nil)

        #expect(coordinator.sequence.isOpen)
        #expect(log.events == (trusted ? ["⌘C"] : []))
    }

    @Test func `start in the shelf seeds the selection without copying`() {
        let coordinator = makeCoordinator()

        coordinator.start(shelfSelection: [5, 4])

        #expect(coordinator.sequence.entries.map(\.cardID) == [5, 4])
        #expect(log.events.isEmpty)
    }

    @Test func `start in the shelf without a selection opens an empty sequence`() {
        let coordinator = makeCoordinator()

        coordinator.start(shelfSelection: [])

        #expect(coordinator.sequence.isOpen)
        #expect(coordinator.sequence.entries.isEmpty)
        #expect(log.events.isEmpty)
    }

    @Test func `pasting the published head advances to the next card`() async throws {
        let coordinator = makeCoordinator()
        let run = Task { try await coordinator.run() }
        defer { run.cancel() }

        coordinator.add([1, 2])
        try await waitUntil { pasteboard.types?.contains(.string) == true }
        #expect(pastedText == "card 1")

        try await waitUntil { coordinator.sequence.entries.map(\.cardID) == [2] }
        try await waitUntil { pastedText == "card 2" }
        try await waitUntil { coordinator.sequence.isOpen == false }
    }

    @Test func `a capture puts the head back on the pasteboard`() async throws {
        let coordinator = makeCoordinator()
        let run = Task { try await coordinator.run() }
        defer { run.cancel() }
        coordinator.add([1])
        try await waitUntil { pasteboard.types?.contains(.string) == true }
        let published = pasteboard.changeCount

        pasteboard.clearContents()
        pasteboard.setString("copied", forType: .string)
        coordinator.didCapture(2)

        try await waitUntil { pasteboard.changeCount > published + 1 }
        #expect(coordinator.sequence.entries.map(\.cardID) == [1, 2])
    }

    @Test func `paste all pastes the queue in sequence order`() async {
        let coordinator = makeCoordinator()
        coordinator.add([3, 1, 2])
        var hidden = false

        await coordinator.pasteAll(coordinator.sequence.pasteAll()) { hidden = true }

        #expect(pastedText == "card 3\ncard 1\ncard 2")
        #expect(hidden)
        #expect(log.events == ["⌘V"])
    }
}
