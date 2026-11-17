# CLAUDE.md

These are the instructions for AI coding agents working on Clipshelf. This file is the single source of truth for agent rules. Never copy these rules anywhere else; link to this file instead.

## Project

Clipshelf is an open-source, native macOS clipboard manager. It matches Paste (pasteapp.io) feature for feature, but looks and behaves like a first-party macOS component.

## Sources of truth

Each fact lives in exactly one place. To change a fact, edit it there and link to it from everywhere else.

| Topic | Source of truth |
|---|---|
| Product decisions (platform, scope, license, distribution) | [Decisions](#decisions) below |
| Agent working rules, skills, quality gate | this file |
| Code rules (architecture, concurrency, SwiftUI, logging, tests, style) | [docs/engineering/code-standards.md](docs/engineering/code-standards.md) (imported below) |
| What blocks a commit or PR | [docs/engineering/review-checklist.md](docs/engineering/review-checklist.md) |
| Native UI rules (Liquid Glass, windows, menus, HIG) | [.claude/skills/macos-native-ui/SKILL.md](.claude/skills/macos-native-ui/SKILL.md) |
| Formatting and lint rules | [.swiftformat](.swiftformat), [.swiftlint.yml](.swiftlint.yml) |
| Vendored third-party code and skills | [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) |
| Git workflow, commit and PR conventions, releases | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Security reporting | [SECURITY.md](SECURITY.md) |
| Branch protection, merge settings | GitHub rulesets on the repo (not files) |
| Release notes categories | [.github/release.yml](.github/release.yml) |
| Product scope, features, behaviour, keyboard map | [docs/product.md](docs/product.md) |
| UI and visual design | [docs/design.md](docs/design.md) |
| Architecture, stack, data model, permissions, distribution | [docs/architecture.md](docs/architecture.md) |
| How the original app works (reference only, not our spec) | `research/PASTE_SPEC.md` (local only, see [Research](#research-local-only)) |
| User-facing description | [README.md](README.md) |

If two sources disagree, the table above decides which one wins. Fix the other source in the same change.

## Decisions

- **Platform:** macOS 26 or later only. Use Liquid Glass and current SwiftUI/AppKit APIs without fallbacks.
- **Look:** use system components, SF Symbols and semantic colors, with no custom brand chrome. If Apple has a control for something, use that control.
- **Sync:** none for now. There is no iCloud/CloudKit and no shared boards, so the data layer is local-only and has no sync fields.
- **License:** GPL-3.0. Code may come from MIT, BSD, Apache-2.0 or GPL-3.0 projects, keeping their copyright notices. Never take code from AGPL or proprietary sources.
- **Distribution:** GitHub Releases and the author's website. Builds are signed with Developer ID and notarized. The app is not sandboxed, because direct paste needs Accessibility. There is no Mac App Store build.
- **Privacy:** no telemetry. The app makes only two kinds of network calls, both opt-in: link previews and Sparkle update checks. "Check for Updates…" is always manual.

## Working rules for agents

- **Code rules:** every rule in [code-standards.md](docs/engineering/code-standards.md) applies. It is imported at the end of this file.
- **Think first:** turn the task into a check you can verify (a failing test, a repro, a visible UI state) before writing code. When several approaches are valid, recommend one and give the tradeoff. If a requirement is unclear, ask instead of guessing.
- **Scope:** make the smallest change that solves the task. Do not refactor, reformat or rename code outside it.
- **Verify before claiming done:** build the app and run the tests. For UI changes, launch the app and look at the result. If you could not verify something, say so.
- **Clipboard data is private:** never log, print, persist outside the app's store or send clipboard contents anywhere. That includes debug logs, test fixtures built from real data, and crash reports.
- **Git:**
  - Follow [CONTRIBUTING.md](CONTRIBUTING.md).
  - Never push to `main`, force-push, create tags or publish releases. Those are the maintainer's.
  - Work on a branch and open a pull request.
  - Every pull request written with AI help must say so in its description (see "AI-assisted contributions" in CONTRIBUTING.md).

## Skills

Load the matching skill before you work in its area.

| Skill | Use when |
|---|---|
| `macos-native-ui` (ours) | building or changing any UI |
| `pre-commit-review` (ours) | before every commit; it is mandatory |
| `swiftui-expert-skill` (AvdLee, MIT) | writing SwiftUI. Its `references/macos-*.md` and `liquid-glass.md` cover macOS |
| `swiftui-pro` (Paul Hudson, MIT) | reviewing SwiftUI for modern APIs, data flow and performance |
| `swift-concurrency` (AvdLee, MIT) | any actor, task, Sendable or isolation work, and compiler concurrency diagnostics |
| `swift-testing-pro` (Paul Hudson, MIT) | writing or reviewing tests |

Vendored skills are third-party. Update them from upstream (see THIRD_PARTY_NOTICES.md) and never edit them in place. Put project-specific rules in code-standards.md instead.

Optional extras on the developer's own machine, not committed:
- Apple's Xcode skills, exported with `xcrun agent skills export --output-dir ~/.claude/skills`.
- The Xcode MCP server for builds, previews and documentation search: `claude mcp add --transport stdio xcode -- xcrun mcpbridge`.

## Quality gate

Nothing gets committed without passing review.

1. **Pre-commit review (Claude Code).** A `PreToolUse` hook (`.claude/hooks/commit-gate.py`) blocks `git commit` unless the `pre-commit-review` skill has approved the exact staged tree. The skill lints, builds, tests, and gets an independent verdict from the `swift-reviewer` subagent. Never bypass it: no `--no-verify`, no `git commit -a`, no hand-written approval markers. Change the hook only when the user asks for it; every change keeps `scripts/test-commit-gate.sh` green and adds a case for the bug it fixes.
2. **Formatting.** A `PostToolUse` hook runs SwiftFormat on every Swift file you edit.
3. **Git pre-commit hook (everyone).** `.githooks/pre-commit` runs `scripts/lint.sh --staged`. Enable it once per clone with `git config core.hooksPath .githooks`.
4. **CI.** The `Lint` workflow runs on every pull request and must pass before merge.

## Research (local only)

`research/` is gitignored and must never be committed. It holds a reverse-engineered analysis of Paste, which includes third-party UI strings, screenshots and videos:
- `research/PASTE_SPEC.md` is the detailed analysis of how the original works (features, UI, behaviour, data model). It is written in Russian. Our own spec is `docs/`; when they differ, `docs/` wins.
- `research/agents/` holds the raw research reports.
- `research/references/` holds screenshots, videos and links (see its README).

Use it to understand how the original behaves. Never copy its strings or assets into the product.

## IP rules

- Never use "Paste", "Pinboard", "Paste Stack" or "Intelligent Clipboard" as names. Use our own terms, such as board and sequence.
- Never copy Paste's icon, images, sounds, brand colors, marketing or help text, UTIs (`com.wiheads.paste.*`) or schema names.
- Functional UI labels such as "Copy" or "Paste as Plain Text" are fine. Write everything else fresh.

## Build and test

- Lint: `scripts/lint.sh` (all files) or `scripts/lint.sh --staged`.
- Build and test: TODO, add the `xcodebuild` commands once the Xcode project exists.

@docs/engineering/code-standards.md
