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
        alertResponse: AccessibilityAlertResponse = copyOnlyResponse
    ) -> PasteCoordinator {
        PasteCoordinator(
            writer: PasteboardWriter(pasteboard: pasteboard),
            representations: { _ in Self.representations },
            trust: FakeTrust(log: log, isTrusted: trusted),
            keystroke: FakeKeystroke(log: log),
            alert: FakeAlert(log: log, response: alertResponse),
            defaults: defaults
        )
    }

    private func paste(
        with coordinator: PasteCoordinator,
        _ action: PasteCoordinator.Action = .paste,
        plainModifier: Bool = false,
        target: FakeTarget? = nil
    ) async throws {
        try await coordinator.perform(
            action,
            cardID: 1,
            plainModifier: plainModifier,
            target: target ?? FakeTarget(log: log, isActive: true),
            hideShelf: { log.events.append("hide") }
        )
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
}
