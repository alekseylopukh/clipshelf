# Roadmap

The ordered task list for building Clipsy. The `build-clipsy` workflow (`.claude/workflows/build-clipsy.js`) implements it one task at a time, top to bottom; each task ends in exactly one reviewed commit (Conventional Commit title, through the `pre-commit-review` gate). Behavior lives in [product.md](product.md), UI in [design.md](design.md), structure in [architecture.md](architecture.md), code rules in [.claude/rules/code-rules.md](../.claude/rules/code-rules.md). This file only orders the work; when it disagrees with those docs, the docs win.

## Settled decisions

Settled decisions live in [CLAUDE.md Decisions](../CLAUDE.md#decisions) and in the "Decided" lines of product.md and architecture.md. Read them there; this file does not repeat them.

## Working defaults for open TODOs

Not maintainer decisions. They are the doc's current text or the simplest choice, so tasks can proceed. Each is easy to change later; a task that implements one names it (`WD-n`).

| ID | Open TODO | Working default |
|---|---|---|
| WD-1 | Poll interval, coalescing ([product §4.1](product.md#41-capture)) | 0.5 s poll, 0.1 s tolerance; a change is processed one tick after it is first seen, so multi-step writes coalesce |
| WD-2 | `org.nspasteboard.source`, Universal Clipboard | Ignore both; source is always the frontmost app, remote copies are captured like local ones |
| WD-3 | Secret pattern match | Skip the capture (rule 7) |
| WD-4 | Bookmark for moved files | None; file URL only |
| WD-5 | Link schemes, 8-digit hex | http, https, mailto, ftp, and any scheme followed by `//`; 8-digit hex is Text |
| WD-6 | Paste from shelf moves card to top | No |
| WD-7 | Edit makes a card identical to another | Save is refused with an inline error; the editor stays open |
| WD-8 | Plain-text modifier when plain is the default | No effect (no inverse modifier) |
| WD-9 | Boards | Palette from [design §4](design.md#board-colors), no "no color"; new cards go to the front; the shelf reopens on the last tab; opening the shelf or switching tabs selects the tab's first card; ⇧-arrows and ⇧-click select the range from the anchor card |
| WD-10 | Search scope | Global (History and all boards) |
| WD-11 | Undo scope | Delete only |
| WD-12 | Delete on a board | Removes from the board only |
| WD-13 | Keep shelf open after paste; height per display | No option; one height for all displays |
| WD-14 | Drag-out formats | Same representations as a paste, one item per card; images also offer a PNG file |
| WD-15 | Compact threshold | Regular card height below 150 pt |
| WD-16 | System Settings deep links | Use a pane URL only if verified on macOS 26; otherwise open System Settings and say where to go |
| WD-17 | Own-write marker type | `app.gonar.clipsy.own-write`, declared in `Store` so `Capture` and `Pasting` share it |
| WD-18 | App Support folder | `~/Library/Application Support/Clipsy/` |
| WD-19 | Update settings location | About pane |
| WD-20 | Linking new modules into the app | One library product `ClipsyKit` lists every package target; the app links only it. A third-party module reaches the app through a ClipsyKit module that re-exports it with `@_exported import` (KeyboardShortcuts through `ShelfUI`). If the app must link a third-party product directly, stop and ask the maintainer to link it in Xcode. |
| WD-21 | Clipboard previous contents after paste | Not restored; no `currentHostOnly` |
| WD-22 | Shelf size and Dock auto-hide ([design §2](design.md#placement-and-size)) | Minimum height 160 pt (one compact row), default 300 pt, maximum 40% of the visible height; placement uses the display's visible frame, so an auto-hidden Dock is not avoided |
| WD-23 | Frontmost app without a bundle ID ([product §4.1](product.md#41-capture) rule 3) | Counts as no frontmost app, so the capture is skipped |
| WD-24 | Database fails to open at launch ([architecture §3.4](architecture.md#34-migrations)) | An alert shows the error with one "Quit Clipsy" button, then the app quits; no files are moved or deleted |
| WD-25 | Plain-text paste of a Card without a plain string ([architecture §4.2](architecture.md#42-paste)) | Writes every representation, as a normal paste would |

## Rules for every task

- Acceptance always also includes: `scripts/build.sh` builds with no new warnings, `scripts/build.sh test` passes, and `scripts/lint.sh` is clean.
- Tests use Swift Testing, fakes at IO boundaries, private named pasteboards and synthetic fixtures ([code-rules R8](../.claude/rules/code-rules.md#r8-tests)).
- A task that settles a TODO or deviates from a doc updates that doc in the same commit.
- A finished task adds `- Status: done` as the last field of its section, in the same commit.
- `- Human check:` marks steps an agent cannot verify (TCC prompts, real paste into other apps, visual review). The workflow records them in the PR description and the maintainer signs off; the task still commits.
- UI tasks load the `macos-native-ui` skill first and run its Verify steps.

## M0. Project skeleton — done

What exists:
- `Clipsy.xcodeproj`, with `App/` as a synchronized group: a menu bar shell and a Settings scene placeholder.
- `Packages/ClipsyKit`, with one module, `Capture` (`HexColor` and its tests), exposed through the umbrella product `ClipsyKit`.
- `scripts/build.sh` and the commands in CLAUDE.md.
- The decisions recorded in CLAUDE.md, product.md and architecture.md.

## M1. Foundations and Store

### T1.1 Record settled decisions in the docs
- Module(s): docs only
- Depends on: none
- Spec: this file, "Settled decisions"
- Deliverable: the dependency line in [architecture §6.1](architecture.md#61-layout) gains `Pasting` → `Store` and `Capture` → `Store`. The recorder row in [design §11](design.md#11-component-mapping) names KeyboardShortcuts.
- Acceptance: both lines read as described.
- Size: S
- Status: done

### T1.2 Build and test in CI, umbrella product
- Module(s): package manifest, CI, CLAUDE.md
- Depends on: T1.1
- Spec: [architecture §6.3](architecture.md#63-ci-github-actions), WD-20
- Deliverable: `Package.swift` adds the targets `Store`, `Media`, `Pasting`, `DesignSystem` and `ShelfUI`, each with a test target and the dependency directions of §6.1, all in the umbrella product `ClipsyKit`. `.github/workflows/build.yml` runs `scripts/build.sh` and `scripts/build.sh test` on a macOS runner, with ad-hoc signing and an SPM cache.
- Acceptance: both commands pass locally; workflow YAML passes `actionlint` if installed; the runner label is the one GitHub documents for an Xcode with the macOS 26 SDK, or a `> TODO:` if it cannot be confirmed
- Size: S
- Status: done

### T1.3 Database bootstrap and initial schema
- Module(s): Store
- Depends on: T1.2
- Spec: [architecture §3.1](architecture.md#31-files), [§3.2](architecture.md#32-schema), [§3.4](architecture.md#34-migrations), WD-18
- Deliverable: GRDB dependency (notice row added); `AppDatabase` opening a `DatabasePool` at a given URL (directory created 0700) or in a temp directory for tests; `DatabaseMigrator` with `v1_initial` creating `card`, `representation`, `board`, `source_app`, `card_search` exactly as §3.2; `CardKind` enum
- Acceptance: tests `migrationCreatesAllTables`, `cardRequiresHistoryOrBoard` (CHECK rejects a row with neither), `representationRequiresExactlyOnePayload`, `searchTokenizerFoldsDiacritics`, `directoryIsOwnerOnly`
- Size: M
- Status: done

### T1.4 Payload file store
- Module(s): Store
- Depends on: T1.3
- Spec: [architecture §3.3](architecture.md#33-payload-storage)
- Deliverable: `PayloadStore`: inline below 4 KB, otherwise SHA-256-named file in `Payloads/<aa>/`, written to temp then renamed; read back; delete unreferenced files and thumbnails (`collectGarbage(referenced:)`)
- Acceptance: tests `smallPayloadStaysInline`, `largePayloadIsContentAddressed`, `identicalPayloadsShareOneFile`, `garbageCollectionKeepsReferencedFiles`, `crashBeforeInsertLeavesOnlyOrphan`
- Size: S
- Status: done

### T1.5 Insert and re-copy cards
- Module(s): Store
- Depends on: T1.4
- Spec: [product §4.3](product.md#43-dedupe-and-re-copy), [architecture §4.1](architecture.md#41-capture) steps 5–6
- Deliverable: `NewCard` input (kind, ordered representations, content hash, preview text, metadata JSON, source app, search body/URL/file names for `card_search`); `CardRepository.record(_:)` that upserts `source_app`, inserts card + representations + search row in one transaction, or on an existing hash sets `last_copied_at` and source app; `representations(of:)` reading payloads back in original order
- Acceptance: tests `newCardIsInsertedWithSearchRow`, `sameHashMovesCardToTop` (created_at unchanged), `boardOnlyCardReturnsToHistory`, `representationsRoundTripInOrder`
- Size: M
- Status: done

### T1.6 History and board queries with observation
- Module(s): Store
- Depends on: T1.5
- Spec: [architecture §3.2](architecture.md#32-schema), [product §3.2](product.md#32-shelf-and-cards)
- Deliverable: `CardSummary` value (id, kind, title, preview, metadata, source app, times, board id); queries for History (newest first) and a board (by position); `AsyncSequence` observation of each via `ValueObservation`
- Acceptance: tests `historyIsNewestFirst`, `boardIsByPosition`, `observationEmitsOnInsert`, `historyExcludesBoardOnlyCards`
- Size: M
- Status: done

### T1.7 Boards in the store
- Module(s): Store
- Depends on: T1.6
- Spec: [product §4.8](product.md#48-boards), [architecture §4.5](architecture.md#45-retention-cleanup) last paragraph, WD-9
- Deliverable: create (empty name → "Untitled"), rename, recolor, reorder, delete; add card (moves from another board, goes to front), remove card (deletes it if not in History), reorder inside a board with fractional positions
- Acceptance: tests `addToSecondBoardMoves`, `removeFromBoardDeletesCardOutsideHistory`, `deleteBoardKeepsHistoryCards`, `deleteBoardDeletesBoardOnlyCards`, `reorderBetweenNeighbors`, `emptyNameBecomesUntitled`
- Size: M
- Status: done

### T1.8 Retention, Erase History, delete and restore
- Module(s): Store
- Depends on: T1.7
- Spec: [product §4.4](product.md#44-retention), [§4.11](product.md#411-deleting), [architecture §4.5](architecture.md#45-retention-cleanup), WD-11, WD-12
- Deliverable: `RetentionPeriod` enum (default 1 Month); `purge(olderThan:)`, `eraseHistory()`, both followed by garbage collection; `delete(cards:in:)` with History/board semantics returning a snapshot that `restore(_:)` puts back (for undo)
- Acceptance: tests `purgeKeepsBoardCardsAndClearsTheirHistory`, `purgeDeletesExpiredHistoryCards`, `eraseHistoryKeepsBoards`, `deleteOnBoardKeepsHistory`, `restoreUndoesDelete`, `purgeCollectsOrphanPayloads`
- Size: M
- Working default: `RetentionPeriod.cutoff` subtracts one calendar day, week, month or year; a card copied exactly at the cutoff is kept. `delete` does not collect garbage, so `restore` can reuse the payload files; a card whose payload file was collected since is not restored. When a card with the same content exists again at restore time (copied again), restore puts the deleted membership back on that card instead of inserting a second one; a card whose id was reused meanwhile comes back under a new id
- Status: done

### T1.9 Full-text search query
- Module(s): Store
- Depends on: T1.6
- Spec: [product §4.9](product.md#49-search-and-filters), [architecture §3.2](architecture.md#32-schema), WD-10
- Deliverable: `search(_ text:)` over History and boards, word-prefix, case- and diacritic-insensitive, newest first, returning `CardSummary` plus board id and match ranges for highlighting; query text escaped for FTS5 syntax
- Acceptance: tests `prefixMatches`, `diacriticsAreFolded`, `matchesAppName`, `fts5OperatorsInInputAreLiteral`, `resultsIncludeBoardOnlyCards`
- Size: M
- Working default: "newest" is `last_copied_at`, or `created_at` for a board-only card; every run of letters and digits in the query is a quoted prefix term, terms combine with AND; match ranges cover the matched prefix in the title and preview text
- Status: done

## M2. Capture

### T2.1 Pasteboard reading and size cap
- Module(s): Capture, Store
- Depends on: T1.5
- Spec: [product §4.1](product.md#41-capture) rule 3, [architecture §4.1](architecture.md#41-capture) step 3, WD-17
- Deliverable: `PasteboardReading` protocol (change count, items, types, data); `NSPasteboard` conformance; `PasteboardSnapshot` reader that drops junk types (source markers, OLE link types, own marker) and any representation over 50 MB, returning nil when nothing is left; marker type constant in Store
- Acceptance: tests on a private named pasteboard: `readsAllItemsAndTypesInOrder`, `dropsJunkTypes`, `dropsOversizedRepresentation`, `emptyAfterFilteringIsNil`
- Size: M
- Status: done

### T2.2 Type classifier
- Module(s): Capture
- Depends on: T2.1
- Spec: [product §4.2](product.md#42-type-detection), WD-5
- Deliverable: `classify(_ snapshot:) -> CardKind` in the §4.2 order, reusing `HexColor`; File vs Multiple files kept in metadata
- Acceptance: parameterized test `classification` covering every row of the §4.2 tables plus `mailto:`, `ftp://`, `custom://x`, a URL with spaces, and 8-digit hex
- Size: S
- Status: done

### T2.3 Content hash, preview and metadata
- Module(s): Capture
- Depends on: T2.2
- Spec: [product §4.3](product.md#43-dedupe-and-re-copy), [architecture §3.2](architecture.md#32-schema) rules
- Deliverable: SHA-256 over sorted `(uti, data)` pairs (CryptoKit); preview text (first ~1000 chars); per-kind metadata (URL, pixel size, file count and names, color value, char/word/line counts); builds `NewCard`
- Acceptance: tests `sameTextFromTwoAppsSameHash`, `richAndPlainDiffer`, `typeOrderDoesNotChangeHash`, `imageMetadataHasPixelSize`, `fileMetadataHasNames`
- Size: S
- Status: done

### T2.4 Skip rules
- Module(s): Capture
- Depends on: T2.1
- Spec: [product §4.1](product.md#41-capture) rule 2, Ignored Apps paragraph, [architecture §5](architecture.md#5-permissions-and-privacy), WD-23
- Deliverable: `CapturePolicy` value (paused, ignored bundle IDs, ignore concealed, ignore transient); `SkipReason` enum; evaluation in the documented order; concealed, transient, auto-generated and legacy types; password-manager bundle IDs each verified from the vendor app's Info.plist or official docs, otherwise left out with a `> TODO:` in product.md
- Acceptance: parameterized test `eachRuleSkips`, test `rulesApplyInDocumentedOrder`, test `togglesOffLetContentThrough`
- Size: M
- Status: done

### T2.5 Pasteboard monitor and pipeline
- Module(s): Capture
- Depends on: T2.3, T2.4, T1.5
- Spec: [architecture §4.1](architecture.md#41-capture), [product §4.1](product.md#41-capture) rules 1, 5, 6, WD-1, WD-2
- Deliverable: `@MainActor` monitor polling change count via an injected clock and `FrontmostAppProviding`; own-write check through an injected closure; reading on main, hashing and DB write off main; last handled change count persisted through an injected store; emits captured card ids as an `AsyncStream` (for the menu bar effect and the Sequence)
- Acceptance: tests with fakes: `changeProducesOneCard`, `multiStepWriteCoalesces`, `ownWriteIsIgnored`, `relaunchDoesNotRecapture`, `pausedProducesNothing`
- Size: M
- Status: done

### T2.6 Start capture in the app
- Module(s): App
- Depends on: T2.5
- Spec: [architecture §3.4](architecture.md#34-migrations), [§4.1](architecture.md#41-capture)
- Deliverable: app startup opens the database (migrations before any UI; on failure an alert and no file changes, WD-24), starts the monitor with default policy, wires own-write closure placeholder
- Acceptance: launching the built app creates the store in App Support with mode 0700
- Human check: copy text, a URL, an image and a Finder file; `sqlite3 <store> "select kind, count(*) from card group by kind"` shows four kinds (never print contents); the store folder is mode 0700 (`stat -f %Lp`); with the store folder at `chmod 000`, launching shows the WD-24 alert and quits, and the folder is unchanged (restore with `chmod 700`)
- Size: S
- Status: done

## M3. Shelf UI

### T3.1 Design tokens and board colors
- Module(s): DesignSystem
- Depends on: T1.2
- Spec: [design §2](design.md#placement-and-size), [§3](design.md#states), [§4](design.md#board-colors)
- Deliverable: spacing, insets, radii, card size, ring width (+1 pt with Increase Contrast), badge size; `BoardColor` enum mapped to system colors
- Acceptance: test `boardColorRoundTripsStoredName` for all seven colors
- Size: S
- Status: done

### T3.2 Shelf panel
- Module(s): ShelfUI
- Depends on: T3.1
- Spec: [product §4.13](product.md#413-shelf-window-behavior), [design §2](design.md#2-shelf), [design §11](design.md#11-component-mapping)
- Deliverable: non-activating `NSPanel` subclass with glass container hosting SwiftUI; placement on the pointer's display, inset above a bottom Dock; joins active Space and full-screen Spaces; `sharingType = .none` by default; show/hide records the target app; closes on Esc, focus loss (except own sheets/menus); open/close motion with Reduce Motion fallback; top-edge resize between one row and 40% of the visible height, persisted (WD-13, WD-22)
- Acceptance: tests `frameIsInsetAboveDock`, `heightIsClampedToRange` for a pure frame calculator
- Human check: opens over a full-screen app without switching Spaces; TextEdit keeps its caret and stays frontmost; clicking elsewhere closes it; a screen recording does not show it; height survives relaunch
- Size: M
- Status: done

### T3.3 Global shelf shortcut
- Module(s): App
- Depends on: T3.2
- Spec: [product §5](product.md#global-customizable)
- Deliverable: KeyboardShortcuts dependency (notice row); `.toggleShelf` name, default ⇧⌘V; second press closes
- Acceptance: build passes with the dependency resolved through the umbrella product (WD-20)
- Human check: ⇧⌘V toggles the shelf from Finder, Safari and a full-screen app
- Size: S
- Status: done

### T3.4 Shelf model: list, selection, navigation
- Module(s): ShelfUI
- Depends on: T1.6, T3.2
- Spec: [product §4.12](product.md#412-multi-select), [§5 In the shelf](product.md#in-the-shelf), WD-9
- Deliverable: `@Observable ShelfModel` fed by store observation: current tab, cards, single and multi selection (← → ⌘↑ ⌘↓ ⇧← ⇧→ ⌘-click ⇧-click ⌘A), newest selected on open, last tab remembered
- Acceptance: tests `arrowsMoveSelection`, `shiftArrowExtends`, `commandClickToggles`, `selectAllSelectsCurrentList`, `selectionSurvivesInsertAtFront`, `openSelectsNewest`
- Size: M
- Status: done

### T3.5 Card view: chrome, text, link, color, unknown
- Module(s): ShelfUI, DesignSystem
- Depends on: T3.4
- Spec: [design §3](design.md#3-cards), [§10](design.md#10-accessibility-and-appearance)
- Deliverable: card strip (`ScrollView` + `LazyHStack`), header (app icon, title or type label, relative time), footer, selection ring, hover lift; bodies for plain and rich text, code-like text, link without preview, color, unknown; VoiceOver label, value and custom actions
- Acceptance: `#Preview`s with mock data for each type; test for the code-like heuristic
- Human check: light and dark, Increase Contrast, VoiceOver reads "Text from TextEdit, 2 minutes ago"
- Size: M

### T3.6 Card view: image and file
- Module(s): Media, ShelfUI
- Depends on: T3.5
- Spec: [design §3 Per-type layouts](design.md#per-type-layouts), [architecture §1](architecture.md#1-overview) thumbnails row
- Deliverable: ImageIO downsampled thumbnail off the main actor, cached in `Thumbnails/`; image body with checkerboard; file and multiple-files bodies with workspace icons (Quick Look thumbnails come in T8.1)
- Acceptance: tests `thumbnailFitsRequestedSize`, `thumbnailIsCachedByHash`
- Human check: a 20 MB screenshot card scrolls without stutter
- Size: M

### T3.7 Top bar, tabs, empty states
- Module(s): ShelfUI
- Depends on: T3.5
- Spec: [design §4](design.md#4-top-bar), [empty states](design.md#empty-states), [product §4.9](product.md#49-search-and-filters)
- Deliverable: glass top bar with search field, History and board capsules, New Board button, More menu; `ShelfModel` falls back to History when its remembered board no longer exists; ⌘← ⌘→ switch tabs (customizable shortcuts read locally, not registered globally); Esc clears search then closes; empty states for History, board, no results, paused
- Acceptance: tests `escClearsSearchFirst`, `tabShortcutsSwitchTabs` on the model
- Human check: keyboard-only pass: Tab cycles search, tabs, cards with visible focus
- Size: M

## M4. Pasting

### T4.1 Pasteboard writer and own-write ledger
- Module(s): Pasting
- Depends on: T1.5, T2.5
- Spec: [product §4.5](product.md#45-paste-mechanics) step 2, [architecture §4.2](architecture.md#42-paste), WD-17, WD-21, WD-25
- Deliverable: `PasteboardWriter` that clears the pasteboard, writes all representations in item and type order (or plain text only), adds the marker, records the change count and answers `isOwnWrite(_:)`; the app wiring moved to T4.3, the first task that writes from the app (the monitor is started by T2.6)
- Acceptance: tests on a private pasteboard: `writesAllRepresentationsInOrder`, `plainWritesOnlyString`, `markerIsPresent`, `ledgerMatchesChangeCount`
- Size: S
- Status: done

### T4.2 Synthesized ⌘V and Accessibility
- Module(s): Pasting
- Depends on: T4.1
- Spec: [product §4.5](product.md#45-paste-mechanics) step 4, [architecture §4.2](architecture.md#42-paste) step 5, [§5](architecture.md#5-permissions-and-privacy)
- Deliverable: key code for "V" from the ASCII-capable layout (`UCKeyTranslate`); `CGEvent` ⌘V with left-Cmd flag; `AccessibilityTrust` protocol (check, prompt); notice for any code adapted from Maccy, Clipy or Flycut
- Acceptance: test `keyCodeForVOnUSLayoutIs9` against the US layout input source
- Human check: paste works into TextEdit, Safari, Terminal and an Electron app; with Dvorak–QWERTY ⌘ layout
- Size: M

### T4.3 Paste flow from the shelf
- Module(s): ShelfUI, Pasting, App
- Depends on: T4.2, T3.4, T2.6
- Spec: [product §4.5](product.md#45-paste-mechanics), [design §9 Rules](design.md#9-onboarding-and-permissions), WD-6, WD-8
- Deliverable: the app creates one `PasteboardWriter` and passes its `isOwnWrite` to the capture monitor in place of T2.6's placeholder; `PasteCoordinator`: Return and double-click paste, ⇧ for plain, ⌘C copies, copy-only setting, plain-by-default setting; hide shelf, reactivate target if needed, then post ⌘V; first paste without Accessibility shows the alert with "Don't ask again"
- Acceptance: tests with fakes: `copyOnlyNeverPostsKeystroke`, `missingTrustAsksOnce`, `shiftForcesPlain`, `pasteHidesShelfBeforeKeystroke`
- Human check: the alert appears once with Accessibility revoked; afterwards Return copies only
- Size: M

### T4.4 Quick Paste
- Module(s): ShelfUI
- Depends on: T4.3
- Spec: [product §4.6](product.md#46-quick-paste), [design quick-paste badges](design.md#quick-paste-badges)
- Deliverable: badges 1–9 on the first visible cards while the modifier is held; modifier + digit pastes, with ⇧ as plain text; modifiers from settings
- Acceptance: tests `badgesCountFromFirstVisibleCard`, `digitBeyondVisibleCountDoesNothing`
- Human check: badges follow scrolling; ⇧⌘3 pastes the third visible card as plain text
- Size: S

## M5. Organize

### T5.1 Context menu, open, delete and undo
- Module(s): ShelfUI
- Depends on: T4.3, T1.8
- Spec: [design card context menu](design.md#card-context-menu), [product §4.11](product.md#411-deleting), WD-11, WD-12
- Deliverable: context menu with MVP items (Paste to App, Paste as Plain Text, Copy, Copy as Plain Text, Open, Add to Board, Remove from Board, Delete), hidden when not applicable; ⌘O opens links and files; ⌫ deletes (confirmation with count for several); ⌘Z restores while the shelf is open
- Acceptance: tests `deleteSeveralNeedsConfirmation`, `undoRestoresDeletedCards`, `multiSelectionMenuHasOnlyBatchItems`
- Human check: menu matches design.md order and symbols
- Size: M

### T5.2 Board management UI
- Module(s): ShelfUI
- Depends on: T1.7, T3.7
- Spec: [product §4.8](product.md#48-boards), [design §4](design.md#board-colors), WD-9
- Deliverable: New/Edit Board sheet (name, swatch row) via ⇧⌘N and the plus button; rename, recolor, delete (confirmation) from the capsule's context menu; reorder capsules by drag
- Acceptance: test `newBoardBecomesCurrentTab` on the model
- Human check: create, rename, recolor, reorder and delete a board using only the keyboard plus one drag
- Size: M

### T5.3 Cards on boards
- Module(s): ShelfUI
- Depends on: T5.2
- Spec: [product §3.5](product.md#35-boards), [§4.8](product.md#48-boards)
- Deliverable: Add to Board submenu (with New Board…) and Remove from Board for single and multi selection; drop cards on a capsule; drag to reorder inside a board
- Acceptance: tests `addSelectionToBoard`, `dropOnCapsuleAdds`
- Human check: reordered board survives relaunch
- Size: M

### T5.4 Search in the shelf
- Module(s): ShelfUI
- Depends on: T1.9, T3.7
- Spec: [product §4.9](product.md#49-search-and-filters), [design §3 Anatomy](design.md#anatomy) board marker
- Deliverable: typing anywhere starts a search; ⌘F focuses the field; live results with one selected; Return pastes; matches highlighted; board dot on results; Tab and ↓ move focus to cards
- Acceptance: tests `typingStartsSearch`, `resultsKeepOneSelected`, `queryDebounceCancelsStale`
- Human check: search for an app name and a word prefix with accents
- Size: M

## M6. Settings, permissions, menu bar — MVP complete

### T6.1 General settings pane
- Module(s): App, Store, Pasting
- Depends on: T5.1
- Spec: [product §6 General](product.md#general), [design §8 General](design.md#general), [product §4.4](product.md#44-retention)
- Deliverable: Settings scene with toolbar tabs; General pane: open at login (`SMAppService.mainApp`), sound toggle (stored, used in T8.8), retention slider with confirmation when lowering, Erase History with confirmation, paste behavior, plain by default, Accessibility status re-checked on activation; hourly retention purge
- Acceptance: test `loweringRetentionNeedsConfirmation` on the settings model; test `purgeScheduleRunsAtLaunch` with a fake clock
- Human check: login item appears in System Settings › General › Login Items
- Size: M

### T6.2 Shortcuts pane
- Module(s): App, Pasting
- Depends on: T6.1, T3.3
- Spec: [product §6 Shortcuts](product.md#shortcuts), [shortcut recorder rules](product.md#shortcut-recorder-rules)
- Deliverable: recorders for Open Shelf and Next/Previous Board (Sequence recorders added in T11.5); Quick Paste and plain-text modifier pop-ups that must differ; Restore Defaults with confirmation; ⌥-only warning
- Acceptance: tests `modifiersMustDiffer`, `restoreDefaultsResetsAll`
- Human check: a recorder rejects ⌘Q with the conflict shown inline
- Size: S

### T6.3 Privacy pane and ignored apps
- Module(s): App, Capture, ShelfUI
- Depends on: T6.1, T2.4
- Spec: [product §6 Privacy](product.md#privacy), [design §8 Privacy](design.md#privacy)
- Deliverable: concealed and temporary toggles, ignored apps list (app picker via `NSOpenPanel`, Apple Passwords preset with a verified bundle ID), help text about browser extensions, screen sharing toggle applied live to the panel; changes flow into `CapturePolicy`
- Acceptance: test `settingsMapToCapturePolicy`
- Human check: adding TextEdit to Ignored Apps stops its copies being captured
- Size: M

### T6.4 Menu bar extra and pause
- Module(s): App, Capture
- Depends on: T6.1
- Spec: [product §6 Menu bar menu](product.md#menu-bar-menu), [design §7](design.md#7-menu-bar-extra)
- Deliverable: template symbol (paused variant, bounce on capture unless Reduce Motion); menu: Open Shelf with shortcut, Pause/Resume Capture (durations in T7.3), Settings…, About Clipsy (standard panel with acknowledgements), Help and Report an Issue (https://github.com/alekseylopukh/clipsy), Quit; ⌘T in the shelf; Show in menu bar and click-opens-shelf settings
- Acceptance: test `pauseStopsCaptureAndResumeRestarts`
- Human check: hiding the item and relaunching the app opens Settings
- Size: M

### T6.5 Onboarding and permission explanations
- Module(s): App, Capture
- Depends on: T6.3, T6.4
- Spec: [design §9](design.md#9-onboarding-and-permissions), [product §4.1](product.md#41-capture) "Pasteboard access", [architecture §5](architecture.md#5-permissions-and-privacy), WD-16
- Deliverable: `PasteboardAccessStatus` from `NSPasteboard.accessBehavior` behind a protocol (API names checked against the macOS 26 SDK), re-read on wake; status row in the Privacy pane; first-launch window with Welcome (shortcut recorder), Paste directly (live Accessibility status), Clipboard access (skipped when not gated), Finish (open at login, retention); one-time pasteboard-access explanation at launch and on wake
- Acceptance: tests `askAndDenyNeedExplanation`, `clipboardStepSkippedWhenNotGated`, `onboardingShownOnlyOnce`
- Human check: full onboarding with Accessibility off then on; status rows turn green without reopening; on a clean user account, record whether polling `changeCount` alone triggers the system prompt and update the TODO in product.md
- Size: M

### T6.6 MVP acceptance pass
- Module(s): Store, tests
- Depends on: T6.5
- Spec: [architecture §6.2](architecture.md#62-testing)
- Deliverable: performance test seeding 100k synthetic cards measuring search latency and history load; baseline recorded in architecture §6.2
- Acceptance: performance test passes and prints timings; no UI change
- Human check: architecture §6.2 manual checklist on a signed build; MVP is usable end to end
- Size: S

## M7. Capture and storage (v1)

### T7.1 Secret detection
- Module(s): Capture
- Depends on: T2.4
- Spec: [product §4.1](product.md#41-capture) "Secret patterns", WD-3
- Deliverable: rule 7 matcher for the listed patterns, gated by the concealed-content setting
- Acceptance: parameterized tests `secretsAreSkipped` and `ordinaryCodeIsKept` (synthetic snippets only)
- Size: S

### T7.2 Storage summary
- Module(s): Store, App
- Depends on: T6.1
- Spec: [product §3.1](product.md#31-capture-and-history), [design §8 General](design.md#general)
- Deliverable: item count and on-disk size (database plus payloads), formatted with `FormatStyle`, refreshed after purge and erase
- Acceptance: test `summaryCountsPayloadBytes`
- Size: S

### T7.3 Pause for a duration
- Module(s): Capture, App
- Depends on: T6.4
- Spec: [product §6 Menu bar menu](product.md#menu-bar-menu), [design §7](design.md#7-menu-bar-extra)
- Deliverable: 15 minutes, 1 hour, 8 hours, until tomorrow, until resumed; resume time shown; survives relaunch
- Acceptance: tests `pauseResumesAtDeadline`, `untilTomorrowUsesCalendar` with a fake clock
- Size: S

### T7.4 Recover from a damaged store
- Module(s): Store, App
- Depends on: T2.6
- Spec: [product §3.1](product.md#31-capture-and-history), [architecture §3.4](architecture.md#34-migrations)
- Deliverable: an unreadable database (not a failed migration) is moved to a timestamped backup folder and a new store is created; the user is told where the backup is
- Acceptance: tests `corruptFileIsMovedAside`, `failedMigrationDoesNotTouchFile`
- Size: S

## M8. Cards (v1)

### T8.1 Quick Look preview and file thumbnails
- Module(s): Media, ShelfUI
- Depends on: T3.6
- Spec: [design Quick Look](design.md#quick-look), [design per-type layouts](design.md#per-type-layouts), [architecture §8](architecture.md#8-open-questions)
- Deliverable: Space toggles a popover anchored to the card; `QLPreviewView` for files and images, SwiftUI views for text, links, colors; arrows move the preview; the shelf stays open; `QLThumbnailGenerator` thumbnails for file cards, cached, fanned stack for multiple files
- Acceptance: test `missingFileFallsBackToIcon`; prototype result (popover inside a non-activating panel) noted in design.md
- Human check: preview of a PDF, an image, rich text and a color
- Size: M

### T8.2 Open With, Show in Finder, Share, drag out
- Module(s): ShelfUI
- Depends on: T5.3
- Spec: [product §3.2](product.md#32-shelf-and-cards), [design card context menu](design.md#card-context-menu), WD-14
- Deliverable: Open With submenu for files, Show in Finder, Share submenu for single and multi selection; drag one or several cards into other apps, images also as PNG files
- Acceptance: tests `openWithHiddenForText`, `dragItemsMatchPasteRepresentations`
- Human check: share a link to Notes; drag an image card to Finder and a text card to TextEdit
- Size: M

### T8.3 Rename
- Module(s): Store, ShelfUI
- Depends on: T5.1
- Spec: [product §4.10](product.md#410-editing-v1), [design edit sheet](design.md#edit-sheet)
- Deliverable: ⌘R or click on the title opens a rename popover; empty title clears it; search row updated. Duplicate is not part of this task (see "Needs the maintainer")
- Acceptance: tests `emptyTitleClears`, `renameUpdatesSearchRow`
- Size: S

### T8.4 Text editor and New Text Card
- Module(s): Store, ShelfUI
- Depends on: T8.3
- Spec: [product §4.10](product.md#410-editing-v1), [design edit sheet](design.md#edit-sheet), WD-7
- Deliverable: ⌘E sheet with rich text editing (B/I/U/S), live counts; save replaces content in place and recomputes hash and search row; ⌘N creates a card in History or the current board
- Acceptance: tests `editKeepsPositionAndBoard`, `editRecomputesHash`, `editToExistingHashIsRefused`, `newCardGoesToCurrentBoard`
- Human check: edits never change the system clipboard
- Size: M

### T8.5 Link and color editing
- Module(s): ShelfUI, Capture
- Depends on: T8.4
- Spec: [product §4.10](product.md#410-editing-v1), [design edit sheet](design.md#edit-sheet)
- Deliverable: link editor (URL and title, type re-detected on save); color editor with system color panel and format picker
- Acceptance: tests `linkEditedToTextBecomesText`, `colorFormatsRoundTrip`
- Size: S

### T8.6 Show in List
- Module(s): ShelfUI
- Depends on: T5.4
- Spec: [product §3.2](product.md#32-shelf-and-cards), [§5](product.md#in-the-shelf)
- Deliverable: ⌘G from a single search result clears the search, switches to its board or History and selects it with neighbors visible
- Acceptance: test `showInListSelectsCardInItsTab`
- Size: S

### T8.7 Compact size
- Module(s): ShelfUI, DesignSystem
- Depends on: T3.5
- Spec: [design §2](design.md#placement-and-size), WD-15
- Deliverable: condensed card layout below the threshold, animated switch (instant with Reduce Motion)
- Acceptance: test `compactBelowThreshold`
- Human check: drag height across the threshold in light and dark
- Size: S

### T8.8 Sounds
- Module(s): App, ShelfUI
- Depends on: T6.1
- Spec: [product §3.2](product.md#32-shelf-and-cards), [§4.5](product.md#45-paste-mechanics) step 7
- Deliverable: capture and paste sounds when enabled; our own assets or system sounds, with origin recorded in THIRD_PARTY_NOTICES.md if third-party
- Acceptance: test `soundsOffPlaysNothing` with a fake player
- Human check: maintainer approves the sounds
- Size: S

## M9. Media (v1)

### T9.1 Text recognition in images
- Module(s): Media, Store, App
- Depends on: T1.9, T6.3
- Spec: [product §3.2](product.md#32-shelf-and-cards), [§3.6](product.md#36-search), [architecture §2](architecture.md#2-stack)
- Deliverable: Vision `RecognizeTextRequest` queue for image cards with `ocr_state`; text written to `card_search.ocr_text`; Privacy toggle (on by default); pending work resumes after relaunch
- Acceptance: tests `ocrTextIsSearchable` (synthetic rendered image), `toggleOffSkipsQueue`, `failedOcrIsMarked`
- Size: M

### T9.2 Link previews (opt-in)
- Module(s): Media, Store, ShelfUI
- Depends on: T3.5, T6.3
- Spec: [product §3.2](product.md#32-shelf-and-cards), [design per-type layouts](design.md#per-type-layouts), [architecture §5](architecture.md#5-permissions-and-privacy)
- Deliverable: `LPMetadataProvider` fetch only when "Fetch link previews" is on; page title into metadata and search; image cached in Thumbnails
- Acceptance: tests `noFetchWhenOff` (fake provider), `titleIsIndexed`
- Human check: with the toggle off, Little Snitch or `nettop` shows no request on copying a link
- Size: M

## M10. Search filters (v1)

### T10.1 Filter query
- Module(s): Store
- Depends on: T1.9
- Spec: [product §4.9](product.md#49-search-and-filters)
- Deliverable: filters Type, App, Date (today, yesterday, 7 days, 30 days, custom), Board, combined with AND and with text
- Acceptance: parameterized test `filtersCombineWithAnd`; test `dateRangesUseCalendar`
- Size: S

### T10.2 Filter tokens and browser
- Module(s): ShelfUI
- Depends on: T10.1, T5.4
- Spec: [product §4.9](product.md#49-search-and-filters), [design §4](design.md#4-top-bar)
- Deliverable: tokens in the search field, suggestions while typing a type or app name, Filters popover, ⌘F twice opens it
- Acceptance: test `typingAppNameSuggestsToken`
- Human check: keyboard-only filtering by type and date
- Size: M

## M11. Paste several and Sequence (v1)

### T11.1 Paste several
- Module(s): Pasting, ShelfUI
- Depends on: T4.3
- Spec: [product §4.12](product.md#412-multi-select), [architecture §4.2](architecture.md#42-paste)
- Deliverable: multi-selection paste: text joined with newline, files as one write, mixed as one item per card; oldest first
- Acceptance: tests `textsJoinOldestFirst`, `filesBecomeOneWrite`, `mixedIsOneItemPerCard`
- Size: S

### T11.2 Sequence state machine
- Module(s): Pasting
- Depends on: T4.1
- Spec: [product §4.7](product.md#47-sequence), [architecture §4.4](architecture.md#44-sequence)
- Deliverable: in-memory queue of card ids: add (end, or head with Reverse Order), seed from selection in shelf order, advance, remove, reorder, undo last paste or removal, paste all joined text, plain-text flag persisted
- Acceptance: tests `copyOrderPastesFirstCopiedFirst`, `reverseOrderInsertsAtHead`, `undoRestoresPosition`, `lastPasteCloses`, `pasteAllJoinsText`
- Size: M

### T11.3 Sequence paste detection
- Module(s): Pasting
- Depends on: T11.2
- Spec: [architecture §4.4](architecture.md#44-sequence) "Paste detection"
- Deliverable: lazy `NSPasteboardItemDataProvider` for the head card that advances on read; fallback global ⌘V key monitor; chosen mechanism and findings recorded in architecture.md
- Acceptance: test `providerReadAdvancesOnce` on a private pasteboard
- Human check: in Safari, Notes, Terminal and an Electron app, focusing or opening the Edit menu does not advance; ⌘V does
- Size: M

### T11.4 Sequence panel
- Module(s): ShelfUI
- Depends on: T11.3
- Spec: [design §6](design.md#6-sequence), [product §5](product.md#in-the-sequence-panel)
- Deliverable: non-activating utility panel, remembered position, header with Undo, More (Reverse Order, Paste All, Plain Text, Clear), Close; rows with next marker, drag reorder, ⌫ removes, Esc clears; empty state; drop cards from the shelf
- Acceptance: test `panelModelReflectsQueue`
- Human check: works over a full-screen app; hidden from screen recording by default
- Size: M

### T11.5 Sequence shortcuts and collection
- Module(s): App, Pasting, ShelfUI
- Depends on: T11.4, T6.2
- Spec: [product §4.7](product.md#47-sequence), [§5](product.md#global-customizable)
- Deliverable: ⇧⌘C starts a Sequence (synthesized ⌘C in the frontmost app, needs Accessibility) or seeds from shelf selection; ⌃⌥⌘V pastes all; captures stream into the open Sequence; Add to Sequence in the context menu and menu bar; recorders in the Shortcuts pane
- Acceptance: test `capturesJoinOpenSequence`
- Human check: collect three lines in TextEdit, paste them in order in Notes with ⌘V
- Size: M

## M12. Integrations (v1)

### T12.1 App Intents
- Module(s): App, Store
- Depends on: T8.4, T5.2
- Spec: [product §3.7](product.md#37-integrations)
- Deliverable: intents Create Card, Create Board, Get Card at Index, Get Latest Card of Type
- Acceptance: tests on the intent handlers' store calls
- Human check: each intent runs in the Shortcuts app
- Size: M

### T12.2 URL scheme
- Module(s): App
- Depends on: T6.4, T8.4
- Spec: [product §3.7](product.md#37-integrations)
- Deliverable: scheme to open the shelf, search, create a text card, open settings
- Acceptance: tests `parsesEachRoute`, `rejectsUnknownRoute`
- Human check: blocked until the maintainer sets the scheme name and grammar (product.md TODO)
- Size: S

## M13. Release readiness

### T13.1 Sparkle, About pane, signing configuration
- Module(s): App, Xcode build settings
- Depends on: T6.4
- Spec: [architecture §1](architecture.md#1-overview) process model, [§2](architecture.md#2-stack), [§7.1](architecture.md#71-third-party-dependencies), [design §8 About](design.md#about), WD-19
- Deliverable: Sparkle 2 dependency after reading its LICENSE (notice row); automatic checks off until opted in; About pane with version, license, links, acknowledgements, Check for Updates and the opt-in toggle; menu item Check for Updates…; feed URL and EdDSA public key as build settings left `> TODO:`; `LSUIElement`, Hardened Runtime, no sandbox, only the entitlements Sparkle and Apple Events need, set through Info.plist or xcconfig files, following CLAUDE.md's project rule for `project.pbxproj`
- Acceptance: test that the updater is not started with checks off; `codesign -d --entitlements -` on a Release build lists only the expected keys
- Human check: maintainer supplies the appcast URL and public key
- Size: M

### T13.2 Release scripts
- Module(s): scripts/release
- Depends on: T13.1
- Spec: [architecture §6.4](architecture.md#64-release-pipeline)
- Deliverable: scripts for archive and export, notarize and staple, zip and DMG, Sparkle signing and appcast; all secrets from environment variables
- Acceptance: `shellcheck` clean; dry-run mode runs the archive and packaging steps with ad-hoc signing
- Size: M

### T13.3 Release workflow
- Module(s): CI
- Depends on: T13.2
- Spec: [architecture §6.4](architecture.md#64-release-pipeline), [CONTRIBUTING releases](../CONTRIBUTING.md#releases)
- Deliverable: workflow on `v*` tags that imports the certificate into a temporary keychain, runs the scripts and creates the GitHub Release with DMG and zip
- Acceptance: workflow lints clean; names every required secret in CONTRIBUTING.md
- Human check: maintainer adds the Developer ID certificate, App Store Connect API key and Sparkle private key as secrets and runs the first tagged release
- Size: M

### T13.4 Docs for a public release
- Module(s): docs
- Depends on: T13.3
- Spec: [README](../README.md), [CLAUDE.md](../CLAUDE.md)
- Deliverable: README build-from-source and install sections; release checklist in CONTRIBUTING.md; remaining TODOs in docs/ reviewed and either resolved or listed in an Open questions section
- Acceptance: every link in README and docs/ resolves
- Size: S

## Needs the maintainer

Found while writing this roadmap. Tasks that hit one stop and ask.

- **Duplicate vs. unique hash:** `card.content_hash` is `UNIQUE` ([architecture §3.2](architecture.md#32-schema)), so the v1 Duplicate feature ([product §3.2](product.md#32-shelf-and-cards)) cannot create a copy. Decide the rule, then schedule Duplicate after T8.3.
- **URL scheme** name and grammar (T12.2).
- **Appcast URL, Sparkle keys, signing and notarization secrets** (T13.1, T13.3).
- **Linking package products into the app** without editing `project.pbxproj` (WD-20): if a third-party module must be imported by the app target directly, the link is a one-time Xcode action.

## Later (not scheduled)

- Image editing: rotate, remove background ([product §3.2](product.md#32-shelf-and-cards))
- System Spotlight indexing of board cards ([product §3.7](product.md#37-integrations))
- Other shelf edges and a vertical list layout ([design §12](design.md#12-open-questions))
- Optional source-app tint on card headers ([design §1](design.md#visual-choices-we-made))
- Homebrew cask ([architecture §6.4](architecture.md#64-release-pipeline))
