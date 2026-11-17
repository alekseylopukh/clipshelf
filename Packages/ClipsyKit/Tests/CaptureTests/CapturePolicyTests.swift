import AppKit
import Store
import Testing
@testable import Capture

struct CapturePolicyTests {
    struct Input: Sendable, CustomTestStringConvertible {
        var policy = CapturePolicy()
        var types: [String] = ["public.utf8-plain-text"]
        var frontmostBundleID: String? = "com.apple.TextEdit"
        var isOwnWriteChangeCount = false

        var skipReason: SkipReason? {
            policy.skipReason(
                types: types.map { NSPasteboard.PasteboardType($0) },
                frontmostBundleID: frontmostBundleID,
                isOwnWriteChangeCount: isOwnWriteChangeCount
            )
        }

        var testDescription: String {
            "types \(types), app \(frontmostBundleID ?? "none"), own count \(isOwnWriteChangeCount)"
        }
    }

    private static func input(_ change: (inout Input) -> Void) -> Input {
        var input = Input()
        change(&input)
        return input
    }

    private static let ruleCases: [(Input, SkipReason)] = [
        (input { $0.policy.isPaused = true }, .paused),
        (input { $0.isOwnWriteChangeCount = true }, .ownWrite),
        (input { $0.types.append(PasteboardMarker.ownWrite) }, .ownWrite),
        (input { $0.frontmostBundleID = nil }, .noFrontmostApp),
        (input { $0.frontmostBundleID = CapturePolicy.applePasswordsBundleID }, .ignoredApp),
        (input { $0.policy.ignoredBundleIDs = ["com.apple.TextEdit"] }, .ignoredApp)
    ]
        + CapturePolicy.concealedTypes.map { type in (input { $0.types.append(type.rawValue) }, .concealed) }
        + CapturePolicy.passwordManagerBundleIDs.map { id in (input { $0.frontmostBundleID = id }, .concealed) }
        + CapturePolicy.transientTypes.map { type in (input { $0.types.append(type.rawValue) }, .transient) }

    @Test func `plain copy is captured`() {
        #expect(Input().skipReason == nil)
    }

    @Test(arguments: ruleCases)
    func `each rule skips`(input: Input, expected: SkipReason) {
        #expect(input.skipReason == expected)
    }

    @Test func `rules apply in documented order`() {
        var input = Input()
        input.policy.isPaused = true
        input.isOwnWriteChangeCount = true
        input.frontmostBundleID = nil
        input.policy.ignoredBundleIDs.insert("com.bitwarden.desktop")
        input.types += ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]

        var reasons: [SkipReason?] = [input.skipReason]
        input.policy.isPaused = false
        reasons.append(input.skipReason)
        input.isOwnWriteChangeCount = false
        reasons.append(input.skipReason)
        input.frontmostBundleID = "com.bitwarden.desktop"
        reasons.append(input.skipReason)
        input.policy.ignoredBundleIDs = []
        reasons.append(input.skipReason)
        input.policy.ignoresConcealed = false
        reasons.append(input.skipReason)
        input.policy.ignoresTransient = false
        reasons.append(input.skipReason)

        #expect(reasons == [.paused, .ownWrite, .noFrontmostApp, .ignoredApp, .concealed, .transient, nil])
    }

    @Test func `toggles off let content through`() {
        var input = Input()
        input.policy.ignoresConcealed = false
        input.policy.ignoresTransient = false
        input.frontmostBundleID = "com.bitwarden.desktop"
        input.types += (CapturePolicy.concealedTypes.union(CapturePolicy.transientTypes)).map(\.rawValue)
        #expect(input.skipReason == nil)
    }

    @Test func `default policy ignores Apple Passwords and filters both kinds`() {
        let policy = CapturePolicy()
        #expect(policy == CapturePolicy(
            isPaused: false,
            ignoredBundleIDs: ["com.apple.Passwords"],
            ignoresConcealed: true,
            ignoresTransient: true
        ))
    }
}
