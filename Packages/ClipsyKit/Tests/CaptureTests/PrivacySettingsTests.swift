import Foundation
import Testing
@testable import Capture

@MainActor
final class PrivacySettingsTests {
    private let suiteName = "PrivacySettingsTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test func `defaults match the default policy`() {
        let settings = PrivacySettings(defaults: defaults)

        #expect(settings.ignoredBundleIDs == [CapturePolicy.applePasswordsBundleID])
        #expect(settings.showsShelfInScreenCapture == false)
        #expect(settings.recognizesTextInImages)
        #expect(settings.fetchesLinkPreviews == false)
        #expect(settings.capturePolicy == CapturePolicy())
    }

    @Test func `settings map to capture policy`() {
        let settings = PrivacySettings(defaults: defaults)

        settings.ignoreApps(withBundleIDs: ["com.apple.TextEdit", "com.apple.Safari", "com.apple.TextEdit"])
        settings.stopIgnoringApps(withBundleIDs: [CapturePolicy.applePasswordsBundleID])
        settings.ignoresConcealed = false
        settings.ignoresTransient = false

        #expect(settings.ignoredBundleIDs == ["com.apple.TextEdit", "com.apple.Safari"])
        #expect(settings.capturePolicy == CapturePolicy(
            ignoredBundleIDs: ["com.apple.TextEdit", "com.apple.Safari"],
            ignoresConcealed: false,
            ignoresTransient: false
        ))
        #expect(settings.capturePolicy.skipReason(
            types: [.string],
            frontmostBundleID: "com.apple.TextEdit",
            isOwnWriteChangeCount: false
        ) == .ignoredApp)
        #expect(settings.capturePolicy.skipReason(
            types: [.string],
            frontmostBundleID: CapturePolicy.applePasswordsBundleID,
            isOwnWriteChangeCount: false
        ) == nil)
    }

    @Test func `changes persist across launches`() {
        let settings = PrivacySettings(defaults: defaults)
        settings.ignoreApps(withBundleIDs: ["com.apple.TextEdit"])
        settings.ignoresConcealed = false
        settings.showsShelfInScreenCapture = true
        settings.recognizesTextInImages = false
        settings.fetchesLinkPreviews = true

        let relaunched = PrivacySettings(defaults: defaults)

        #expect(relaunched.ignoredBundleIDs == [CapturePolicy.applePasswordsBundleID, "com.apple.TextEdit"])
        #expect(relaunched.ignoresConcealed == false)
        #expect(relaunched.ignoresTransient)
        #expect(relaunched.showsShelfInScreenCapture)
        #expect(relaunched.recognizesTextInImages == false)
        #expect(relaunched.fetchesLinkPreviews)
    }

    @Test func `removing the preset is remembered`() {
        PrivacySettings(defaults: defaults).stopIgnoringApps(withBundleIDs: [CapturePolicy.applePasswordsBundleID])

        #expect(PrivacySettings(defaults: defaults).ignoredBundleIDs.isEmpty)
    }
}
