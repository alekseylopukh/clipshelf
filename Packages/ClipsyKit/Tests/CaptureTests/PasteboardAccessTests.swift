import AppKit
import Testing
@testable import Capture

@MainActor
final class PasteboardAccessTests {
    private let suiteName = "PasteboardAccessTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test(arguments: [
        (NSPasteboard.AccessBehavior.default, false),
        (.ask, true),
        (.alwaysAllow, false),
        (.alwaysDeny, true)
    ])
    func `ask and deny need explanation`(behavior: NSPasteboard.AccessBehavior, needsExplanation: Bool) {
        #expect(PasteboardAccessStatus(behavior).needsExplanation == needsExplanation)
    }

    @Test func `explanation is requested once per launch`() {
        let pasteboard = FakeAccessPasteboard(accessBehavior: .ask)
        let access = PasteboardAccess(pasteboard: pasteboard, defaults: defaults)

        #expect(access.takeExplanationRequest())
        #expect(access.takeExplanationRequest() == false)
    }

    @Test func `explanation waits until access needs it`() {
        let pasteboard = FakeAccessPasteboard(accessBehavior: .default)
        let access = PasteboardAccess(pasteboard: pasteboard, defaults: defaults)

        #expect(access.takeExplanationRequest() == false)
        pasteboard.accessBehavior = .alwaysDeny
        #expect(access.takeExplanationRequest())
        #expect(access.status == .denied)
    }

    @Test func `suppressed explanation is never requested`() {
        let pasteboard = FakeAccessPasteboard(accessBehavior: .ask)
        PasteboardAccess(pasteboard: pasteboard, defaults: defaults).suppressExplanation()

        let access = PasteboardAccess(pasteboard: pasteboard, defaults: defaults)

        #expect(access.takeExplanationRequest() == false)
    }
}

final class FakeAccessPasteboard: PasteboardAccessReading {
    var accessBehavior: NSPasteboard.AccessBehavior

    init(accessBehavior: NSPasteboard.AccessBehavior) {
        self.accessBehavior = accessBehavior
    }
}
