# AGENTS.md

These are the instructions for AI coding agents working on Clipshelf (Claude Code, Codex, Cursor, Copilot and others). This file is the single source of truth for agent rules. Tool-specific files such as `CLAUDE.md` only import it. Never copy these rules anywhere else; link to this file instead.

## Project

Clipshelf is an open-source, native macOS clipboard manager. It matches Paste (pasteapp.io) feature for feature, but looks and behaves like a first-party macOS component.

## Sources of truth

Each fact lives in exactly one place. To change a fact, edit it there and link to it from everywhere else.

| Topic | Source of truth |
|---|---|
| Product decisions (platform, scope, license, distribution) | [Decisions](#decisions) below |
| Agent working rules | this file |
| Git workflow, commit and PR conventions, releases | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Security reporting | [SECURITY.md](SECURITY.md) |
| Branch protection, merge settings | GitHub rulesets on the repo (not files) |
| Release notes categories | [.github/release.yml](.github/release.yml) |
| Feature, UI and behaviour reference of the original app | `research/PASTE_SPEC.md` (local only, see [Research](#research-local-only)) |
| User-facing description | [README.md](README.md) |

If two sources disagree, the table above decides which one wins. Fix the other source in the same change.

## Decisions

- **Platform:** macOS 26 or later only. Use Liquid Glass and current SwiftUI/AppKit APIs without fallbacks.
- **Look:** use system components, SF Symbols and semantic colors, with no custom brand chrome. If Apple has a control for something, use that control.
- **Sync:** none for now. There is no iCloud/CloudKit and no shared boards, so the data layer is local-only and has no sync fields.
- **License:** GPL-3.0. Code may come from MIT, BSD, Apache-2.0 or GPL-3.0 projects, keeping their copyright notices. Never take code from AGPL or proprietary sources.
- **Distribution:** GitHub Releases and the author's website. Builds are signed with Developer ID and notarized. The app is not sandboxed, because direct paste needs Accessibility. There is no Mac App Store build.
- **Privacy:** no telemetry. The app makes no network calls except opt-in link previews.

## Working rules for agents

- **Scope:** make the smallest change that solves the task. Do not refactor, reformat or rename code outside it.
- **Verify before claiming done:** build the app and run the tests. For UI changes, launch the app and look at the result. If you could not verify something, say so.
- **Dependencies:** do not add a third-party package without the maintainer's approval. Prefer Apple frameworks.
- **Clipboard data is private:** never log, print, persist outside the app's store or send clipboard contents anywhere. That includes debug logs, test fixtures built from real data, and crash reports.
- **Network:** add no network calls beyond what [Decisions](#decisions) allows.
- **Comments:** none by default. Add one only where a reader would otherwise introduce a bug.
- **Secrets:** never commit certificates, notarization credentials, API keys or `.env` files.
- **Git:**
  - Follow [CONTRIBUTING.md](CONTRIBUTING.md).
  - Never push to `main`, force-push, create tags or publish releases. Those are the maintainer's.
  - Work on a branch and open a pull request.
  - Every pull request written with AI help must say so in its description (see "AI-assisted contributions" in CONTRIBUTING.md).

## Research (local only)

`research/` is gitignored and must never be committed. It holds a reverse-engineered analysis of Paste, which includes third-party UI strings, screenshots and videos:
- `research/PASTE_SPEC.md` is the master reference for features, UI, behaviour, data model and stack. It is written in Russian.
- `research/agents/` holds the raw research reports.
- `research/references/` holds screenshots, videos and links (see its README).

Use it to understand how the original behaves. Never copy its strings or assets into the product.

## IP rules

- Never use "Paste", "Pinboard", "Paste Stack" or "Intelligent Clipboard" as names. Use our own terms, such as board and sequence.
- Never copy Paste's icon, images, sounds, brand colors, marketing or help text, UTIs (`com.wiheads.paste.*`) or schema names.
- Functional UI labels such as "Copy" or "Paste as Plain Text" are fine. Write everything else fresh.

## Build and test

> TODO: add the build, test and lint commands once the Xcode project exists.
