# CLAUDE.md

Clipshelf is an open-source, native macOS clipboard manager. It has the same features as Paste (pasteapp.io), but it looks like a first-party macOS component.

## Decisions
- **Platform:** macOS 26 and later, Swift 6. Uses Liquid Glass and current SwiftUI/AppKit APIs with no fallbacks.
- **Look:** system components, SF Symbols and semantic colors. No custom brand chrome.
- **Sync:** none for now. The data layer is local-only.
- **License:** GPL-3.0. Code may be reused from MIT, BSD, Apache-2.0 or GPL-3.0 projects, keeping their notices. Never from AGPL or proprietary sources.
- **Distribution:** GitHub Releases plus the author's site. Signed with Developer ID and notarized. Not sandboxed, because direct paste needs Accessibility. No Mac App Store build.
- **Privacy:** no telemetry. The only network calls are link previews and Sparkle update checks, and both are opt-in. "Check for Updates…" is always manual.

## Where things live
Each fact lives in exactly one place. To change it, edit it there and link to it from elsewhere.

| Topic | Source |
|---|---|
| Code rules and review checklist | [.claude/rules/code-rules.md](.claude/rules/code-rules.md), loaded automatically for `*.swift` |
| Features, behaviour, keyboard map | [docs/product.md](docs/product.md) |
| UI and visual design | [docs/design.md](docs/design.md) |
| Modules, stack, data model, release pipeline | [docs/architecture.md](docs/architecture.md) |
| Git workflow, PRs, releases | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Vendored code and skills | [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) |

## Working rules
- **Think first.** Turn the task into a check you can verify before coding. When the task is unclear, ask.
- **Verify before saying done.** Build, run the tests and, for UI work, look at the running app. Say plainly what you did not verify.
- **Clipboard data is private.** It never reaches logs, crash reports, fixtures or the network.
- **Swift code.** Read `.claude/rules/code-rules.md` before writing Swift. It loads on its own when you open a `.swift` file, but it may not load when you create a new one.
- **Git.** Work on a branch and open a PR that states the AI assistance. Never push to `main`, force-push, tag or release.
- **Gate.** Commits go through the `pre-commit-review` skill. A hook blocks any commit whose staged tree the skill has not approved. Never bypass the gate. Change the hook only when the user asks, and keep `scripts/test-commit-gate.sh` green.

## Skills
- Ours: `macos-native-ui` for any UI work, and `pre-commit-review` before every commit.
- Vendored, do not edit: `swiftui-expert-skill`, `swiftui-pro`, `swift-concurrency`, `swift-testing-pro`.
- Optional, local only:
  - Apple's Xcode skills: `xcrun agent skills export --output-dir ~/.claude/skills`
  - Xcode MCP: `claude mcp add --transport stdio xcode -- xcrun mcpbridge`

## Research (local only, never commit)
`research/` holds a private analysis of Paste: `PASTE_SPEC.md`, written in Russian, plus screenshots. Use it to understand behaviour. Our spec is `docs/`, and `docs/` wins when they disagree.

## IP rules
- Never use "Paste", "Pinboard", "Paste Stack" or "Intelligent Clipboard" as names. Our terms are Shelf, Card, Board and Sequence.
- Never copy Paste's icon, images, sounds, brand colors, text, UTIs (`com.wiheads.paste.*`) or schema names. Functional labels such as "Copy" are fine.

## Commands
- Lint: `scripts/lint.sh`, or `scripts/lint.sh --staged` for staged files only.
- Gate tests: `scripts/test-commit-gate.sh`
- Build and test: TODO, add the `xcodebuild` commands once the Xcode project exists.
- First setup in each clone: `git config core.hooksPath .githooks`
