import AppKit
import Store
import Testing
@testable import Pasting

@MainActor
final class PasteCoordinatorTests {
    private final class EventLog {
        var events: [String] = []
    }

    private struct FakeTrust: AccessibilityTrust {
        let log: EventLog
        var isTrusted: Bool

        func requestTrust() -> Bool {
            log.events.append("requestTrust")
            return false
        }
    }

    private struct FakeKeystroke: PasteKeystrokePosting {
        let log: EventLog

        func postCommandV() {
            log.events.append("keystroke")
        }
    }

    private struct FakeAlert: AccessibilityAlertPresenting {
        let log: EventLog
        var response: AccessibilityAlertResponse

        func presentAccessibilityAlert() -> AccessibilityAlertResponse {
            log.events.append("alert")
            return response
        }
    }

    private struct FakeSoundPlayer: SoundPlaying {
        let log: EventLog

        func play(_ effect: SoundEffect) {
            log.events.append("sound \(effect.rawValue)")
        }
    }

    private final class FakeTarget: PasteTarget {
        let log: EventLog
        var isActive: Bool

        init(log: EventLog, isActive: Bool) {
            self.log = log
            self.isActive = isActive
        }

        func activate() async {
            log.events.append("activate")
            isActive = true
        }
    }

    private static let copyOnlyResponse = AccessibilityAlertResponse(
        opensSystemSettings: false,
        suppressesFutureAlerts: false
    )
    private nonisolated static let representations = [
        Representation(itemIndex: 0, uti: "public.rtf", data: Data([1])),
        Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data([2]))
    ]

    private let suiteName = "PasteCoordinatorTests-\(UUID().uuidString)"
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

    private func makeCoordinator(
        trusted: Bool = true,
        alertResponse: AccessibilityAlertResponse = copyOnlyResponse,
        representations: @escaping PasteCoordinator
            .RepresentationLoading = { _ in PasteCoordinatorTests.representations }
    ) -> PasteCoordinator {
        PasteCoordinator(
            writer: PasteboardWriter(pasteboard: pasteboard),
            representations: representations,
            trust: FakeTrust(log: log, isTrusted: trusted),
            keystroke: FakeKeystroke(log: log),
            alert: FakeAlert(log: log, response: alertResponse),
            sound: FakeSoundPlayer(log: log),
            defaults: defaults
        )
    }

    private func paste(
        with coordinator: PasteCoordinator,
        _ action: PasteCoordinator.Action = .paste,
        cards: [CardSummary] = [CardSummary(id: 1, kind: .text, createdAt: .distantPast)],
        plainModifier: Bool = false,
        target: FakeTarget? = nil
    ) async throws {
        try await coordinator.perform(
            action,
            cards: cards,
            plainModifier: plainModifier,
            target: target ?? FakeTarget(log: log, isActive: true),
            hideShelf: { log.events.append("hide") }
        )
    }

    private var writtenItems: [[String: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.filter { $0.rawValue != PasteboardMarker.ownWrite }
                .compactMap { type in item.data(forType: type).map { (type.rawValue, $0) } })
        }
    }

    private static func card(_ id: Int64, _ kind: CardKind, copiedAt seconds: TimeInterval) -> CardSummary {
        CardSummary(id: id, kind: kind, createdAt: .distantPast, lastCopiedAt: Date(timeIntervalSince1970: seconds))
    }

    private var writtenTypes: [String] {
        (pasteboard.pasteboardItems ?? []).flatMap(\.types).map(\.rawValue)
            .filter { $0 != PasteboardMarker.ownWrite }
    }

    @Test func `paste writes, hides and posts the keystroke`() async throws {
        try await paste(with: makeCoordinator())

        #expect(writtenTypes.contains("public.rtf"))
        #expect(log.events == ["hide", "keystroke"])
    }

    @Test func `paste hides shelf before keystroke`() async throws {
        let target = FakeTarget(log: log, isActive: false)
        try await paste(with: makeCoordinator(), target: target)

        #expect(log.events == ["hide", "activate", "keystroke"])
    }

    @Test func `copy only never posts keystroke`() async throws {
        defaults.set(PasteBehavior.copyOnly.rawValue, forKey: PasteSettings.behaviorKey)
        let coordinator = makeCoordinator()

        try await paste(with: coordinator)
        try await paste(with: coordinator, .copy)

        #expect(writtenTypes.isEmpty == false)
        #expect(log.events == ["hide", "hide"])
    }

    @Test func `command C copies without keystroke`() async throws {
        try await paste(with: makeCoordinator(), .copy)

        #expect(writtenTypes.isEmpty == false)
        #expect(log.events == ["hide"])
    }

    @Test func `sounds on plays the paste sound after paste and copy`() async throws {
        defaults.set(true, forKey: PasteSettings.soundEffectsKey)
        let coordinator = makeCoordinator()

        try await paste(with: coordinator)
        try await paste(with: coordinator, .copy)

        #expect(log.events == ["hide", "sound CardPasted", "keystroke", "hide", "sound CardPasted"])
    }

    @Test func `shift forces plain`() async throws {
        try await paste(with: makeCoordinator(), plainModifier: true)

        #expect(writtenTypes == ["public.utf8-plain-text"])
    }

    @Test(arguments: [false, true])
    func `plain by default ignores the modifier`(plainModifier: Bool) async throws {
        defaults.set(true, forKey: PasteSettings.plainTextByDefaultKey)
        try await paste(with: makeCoordinator(), plainModifier: plainModifier)

        #expect(writtenTypes == ["public.utf8-plain-text"])
    }

    @Test func `missing trust asks once`() async throws {
        let coordinator = makeCoordinator(trusted: false)

        try await paste(with: coordinator)
        try await paste(with: coordinator)

        #expect(writtenTypes.isEmpty == false)
        #expect(log.events == ["hide", "alert", "activate", "hide"])
    }

    @Test func `suppressed alert is not shown again after relaunch`() async throws {
        let response = AccessibilityAlertResponse(opensSystemSettings: false, suppressesFutureAlerts: true)
        try await paste(with: makeCoordinator(trusted: false, alertResponse: response))
        log.events = []

        try await paste(with: makeCoordinator(trusted: false, alertResponse: response))

        #expect(log.events == ["hide"])
    }

    @Test func `open system settings requests trust`() async throws {
        let response = AccessibilityAlertResponse(opensSystemSettings: true, suppressesFutureAlerts: false)
        try await paste(with: makeCoordinator(trusted: false, alertResponse: response))

        #expect(log.events == ["hide", "alert", "requestTrust"])
    }

    @Test func `single text card keeps every representation`() async throws {
        try await paste(with: makeCoordinator())

        #expect(writtenItems == [["public.rtf": Data([1]), "public.utf8-plain-text": Data([2])]])
    }

    @Test func `texts join oldest first`() async throws {
        let texts: [Int64: String] = [1: "newest", 2: "oldest", 3: "middle"]
        let coordinator = makeCoordinator { id in
            [
                Representation(itemIndex: 0, uti: "public.rtf", data: Data([0])),
                Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data((texts[id] ?? "").utf8))
            ]
        }
        let cards = [
            Self.card(1, .text, copiedAt: 300),
            CardSummary(id: 2, kind: .link, createdAt: Date(timeIntervalSince1970: 100)),
            Self.card(3, .color, copiedAt: 200)
        ]

        try await paste(with: coordinator, cards: cards)

        #expect(writtenItems == [["public.utf8-plain-text": Data("oldest\nmiddle\nnewest".utf8)]])
    }

    @Test func `files become one write`() async throws {
        let files: [Int64: [Representation]] = [
            1: [Representation(itemIndex: 0, uti: "public.file-url", data: Data("file:///b".utf8))],
            2: [
                Representation(itemIndex: 0, uti: "public.file-url", data: Data("file:///a1".utf8)),
                Representation(itemIndex: 1, uti: "public.file-url", data: Data("file:///a2".utf8))
            ]
        ]
        let coordinator = makeCoordinator { files[$0] ?? [] }

        try await paste(with: coordinator, cards: [Self.card(1, .file, copiedAt: 2), Self.card(2, .file, copiedAt: 1)])

        #expect(writtenItems == [
            ["public.file-url": Data("file:///a1".utf8)],
            ["public.file-url": Data("file:///a2".utf8)],
            ["public.file-url": Data("file:///b".utf8)]
        ])
        #expect(log.events == ["hide", "keystroke"])
    }

    @Test func `mixed is one item per card`() async throws {
        let mixed: [Int64: [Representation]] = [
            1: [Representation(itemIndex: 0, uti: "public.png", data: Data([1]))],
            2: [
                Representation(itemIndex: 0, uti: "public.rtf", data: Data([2])),
                Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data([3]))
            ]
        ]
        let coordinator = makeCoordinator { mixed[$0] ?? [] }

        try await paste(with: coordinator, cards: [Self.card(1, .image, copiedAt: 2), Self.card(2, .text, copiedAt: 1)])

        #expect(writtenItems == [
            ["public.rtf": Data([2]), "public.utf8-plain-text": Data([3])],
            ["public.png": Data([1])]
        ])
    }
}
