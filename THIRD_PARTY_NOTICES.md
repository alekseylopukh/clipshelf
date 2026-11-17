# Third-party notices

Clipsy is licensed under [GPL-3.0](LICENSE). It includes the following third-party material under GPL-3.0-compatible licenses. Each vendored directory keeps its original `LICENSE` file.

## Agent skills (`.claude/skills/`)

These are vendored unchanged except for one cleanup: plugin manifests and images were removed. Update them by copying from upstream; never edit them in place.

| Directory | Upstream | Commit | License |
|---|---|---|---|
| `.claude/skills/swiftui-expert-skill` | [AvdLee/SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill) `skills/swiftui-expert-skill` | `62bd760f005093d1e2e4de5db156e456a5f96400` | MIT, © 2026 Antoine van der Lee |
| `.claude/skills/swift-concurrency` | [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) `skills/swift-concurrency` | `3b1580d8398e0b5408b3bf0bada0e941a1cfc642` | MIT, © 2026 Antoine van der Lee |
| `.claude/skills/swiftui-pro` | [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) `swiftui-pro` | `f2920b63995263f57b3e198674e89a602efba6d2` | MIT, © 2026 Paul Hudson |
| `.claude/skills/swift-testing-pro` | [twostraws/Swift-Testing-Agent-Skill](https://github.com/twostraws/Swift-Testing-Agent-Skill) `swift-testing-pro` | `2d6bba14a3c8bf3694f218b92fffe617c41ae43e` | MIT, © 2026 Paul Hudson |

## Swift packages

Every package added later gets a row here.

| Package | Version | Use | License |
|---|---|---|---|
| [groue/GRDB.swift](https://github.com/groue/GRDB.swift) | 7.12.0 | SQLite, FTS5, migrations (`Store`) | MIT, © Gwendal Roué |
| [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.4.0 | Global hotkeys, recorder (`ShelfUI`, re-exported to the app) | MIT, © Sindre Sorhus |

`App/Credits.rtf` repeats the notices of the packages and adapted code that ship in the app, for the About panel. Update it with this file.

## Adapted code

Code adapted from other projects. Each file keeps a header line naming its source.

| File | Upstream | Adapted | License |
|---|---|---|---|
| `Packages/ClipsyKit/Sources/Pasting/PasteKeystroke.swift` | [p0deje/Maccy](https://github.com/p0deje/Maccy) | Cmd+V paste recipe: `.combinedSessionState` source, local event suppression, post to `.cgSessionEventTap` | MIT, Copyright (c) 2025 Alex Rodionov |
| `Packages/ClipsyKit/Sources/Pasting/PasteKeystroke.swift` | [TermiT/Flycut](https://github.com/TermiT/Flycut) ([PR #18](https://github.com/TermiT/Flycut/pull/18)) | Left-Cmd device flag on the synthesized events | MIT, Copyright (C) 2011, General Arcade, Gennadiy Potapov |
