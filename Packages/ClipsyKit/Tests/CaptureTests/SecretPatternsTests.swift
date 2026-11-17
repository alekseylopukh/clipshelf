import AppKit
import Testing
@testable import Capture

@MainActor
struct SecretPatternsTests {
    /// fixtures are split so secret scanners do not flag the source as a leaked token
    private nonisolated static let filler = String(repeating: "a1B2", count: 10)

    nonisolated static let secrets: [String] = [
        "password = \"hunter2!\"",
        "let apiKey = \"q8Zt-41xP\"",
        "\"client_secret\": \"c9f0e1d2b3a4\"",
        "db:\n  password: Tr0ub4dor&3x",
        "DB_PASSWORD=hunter2",
        "export GITHUB_TOKEN=abc",
        "private_key => 'kq_9fj3k2'",
        "eyJ" + "hbGciOiJIUzI1NiJ9.eyJ" + "zdWIiOiIxMjM0NTY3ODkwIn0.c2lnbmF0dXJl",
        "gh" + "p_" + filler.prefix(36),
        "github" + "_pat_" + filler.prefix(30),
        "xo" + "xb-" + filler.prefix(24),
        "AK" + "IAIOSFODNN7EXAMPLE",
        "sk" + "-proj-" + filler.prefix(32),
        "sk" + "_live_" + filler.prefix(24),
        "Authorization: Bearer " + filler.prefix(20),
        "curl -H 'Authorization: Basic dXNlcjpwYXNz' https://example.com"
    ]

    nonisolated static let ordinaryCode: [String] = [
        "let password = passwordField.stringValue",
        "func validate(password: String) -> Bool",
        "case password = \"password\"",
        "token = UUID().uuidString",
        "let passwordLabel = \"Pass-word1\"",
        "if PASSWORD.isEmpty { return }",
        "PASSWORD=$DB_PASSWORD",
        "max_tokens: 1024",
        "password: \"Enter your password\"",
        "Use HTTP Basic authentication or a Bearer token.",
        "let sorted = tasks.sorted { $0.date < $1.date }",
        "git checkout -b task-1234-fix-login",
        "#1A2B3C"
    ]

    private func secretSkipReason(for text: String, policy: CapturePolicy = CapturePolicy()) throws -> SkipReason? {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let snapshot = try #require(PasteboardSnapshot(pasteboard: pasteboard))
        return policy.secretSkipReason(for: snapshot)
    }

    @Test(arguments: secrets)
    func `secrets are skipped`(text: String) throws {
        #expect(try secretSkipReason(for: text) == .secret)
    }

    @Test(arguments: ordinaryCode)
    func `ordinary code is kept`(text: String) throws {
        #expect(try secretSkipReason(for: text) == nil)
    }

    @Test(arguments: secrets)
    func `concealed setting off keeps secrets`(text: String) throws {
        #expect(try secretSkipReason(for: text, policy: CapturePolicy(ignoresConcealed: false)) == nil)
    }

    @Test func `secret inside a longer text is found`() throws {
        let text = "Notes from setup\n\n" + Self.ordinaryCode.joined(separator: "\n") + "\nAPI_KEY=k3y\n"
        #expect(try secretSkipReason(for: text) == .secret)
    }
}
