import AppKit
import Testing
@testable import Capture

@MainActor
final class OnboardingFlowTests {
    private let suiteName = "OnboardingFlowTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test(arguments: [NSPasteboard.AccessBehavior.default, .alwaysAllow])
    func `clipboard step skipped when not gated`(behavior: NSPasteboard.AccessBehavior) {
        let flow = makeFlow(behavior: behavior)

        flow.advance()
        #expect(flow.step == .pasteDirectly)
        flow.advance()
        #expect(flow.step == .finish)
    }

    @Test(arguments: [NSPasteboard.AccessBehavior.ask, .alwaysDeny])
    func `clipboard step is shown when access is gated`(behavior: NSPasteboard.AccessBehavior) {
        let flow = makeFlow(behavior: behavior)

        flow.advance()
        flow.advance()
        #expect(flow.step == .clipboardAccess)
        flow.advance()
        #expect(flow.step == .finish)
    }

    @Test func `onboarding shown only once`() {
        let first = makeFlow(behavior: .default)
        #expect(first.presentsAtLaunch)

        first.markPresented()

        #expect(first.presentsAtLaunch)
        #expect(makeFlow(behavior: .default).presentsAtLaunch == false)
    }

    private func makeFlow(behavior: NSPasteboard.AccessBehavior) -> OnboardingFlow {
        let access = PasteboardAccess(pasteboard: FakeAccessPasteboard(accessBehavior: behavior), defaults: defaults)
        return OnboardingFlow(access: access, defaults: defaults)
    }
}
