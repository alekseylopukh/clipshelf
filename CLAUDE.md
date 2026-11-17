# Clipshelf

Open-source native macOS clipboard manager: a feature-level alternative to Paste (pasteapp.io) that looks and behaves like a first-party macOS component.

## Decisions

- **Platform:** macOS 26+ only, so Liquid Glass and current SwiftUI/AppKit APIs are used without fallbacks.
- **Look:** system components, SF Symbols, semantic colors. No custom brand chrome. If Apple has a control for it, use that control.
- **No sync** for now: no iCloud/CloudKit and no shared boards. The data layer is local-only, with no sync fields.
- **License:** GPL-3.0. Code may be taken from MIT, BSD, Apache-2.0 or GPL-3.0 projects, keeping their copyright notices. Never take code from AGPL or proprietary sources.
- **Distribution:** GitHub Releases plus the author's website. Builds are Developer ID signed and notarized, not sandboxed, because direct paste needs Accessibility. No Mac App Store build planned.
- **Privacy:** no telemetry, no network calls except opt-in link previews.

## Research (local only)

`research/` is gitignored and must never be committed:
- `research/PASTE_SPEC.md` is the master reference for features, UI, behaviour, data model and stack (Russian).
- `research/agents/` holds the raw research reports.
- `research/references/` holds screenshots, videos and links (see its README).

## IP rules

- Never use "Paste", "Pinboard", "Paste Stack" or "Intelligent Clipboard" as names. Use our own terms: board, sequence, and so on.
- Never copy Paste's icon, images, sounds, colors-as-brand, marketing or help text, UTIs (`com.wiheads.paste.*`) or schema names.
- Functional UI labels ("Copy", "Paste as Plain Text") are fine. Write everything else fresh.
