---
paths:
  - "**/*.swift"
---

# Code rules

Every code change and every review in this repo must follow these rules. They apply to humans and AI alike.

- **Writing code:** follow every rule. Before calling a change done, walk the [checklist](#checklist) against your diff.
- **Reviewing:** check every added or changed line against these rules. Cite findings by rule ID, for example `R2.3`.
  - **[B]** marks a blocking rule: one violation fails the review.
  - **[N]** marks a non-blocking rule: report it as a suggestion.
  - Flag only lines the diff touches. Never flag anything listed under [Do NOT flag](#do-not-flag).

The details live in the vendored skills: `swiftui-pro` and `swiftui-expert-skill` for SwiftUI, `swift-concurrency` for concurrency, and `swift-testing-pro` for tests. The UI how-to and its verification steps live in `macos-native-ui`. These rules take precedence over the skills.

## R0. Correctness
- **R0.1 [B]** The change cannot produce wrong behaviour. That rules out a logic error, an unhandled edge case on a real path, a broken migration, a data race or isolation violation, and state that is used after an `await` without being checked again.
- **R0.2 [B]** It builds with no new warnings, and the tests and `scripts/lint.sh --staged` pass.

## R1. Architecture
- **R1.1 [B]** Code lives in local SPM modules, and dependencies flow only in the directions [docs/architecture.md](../../docs/architecture.md) allows. The app target only wires dependencies and declares scenes.
- **R1.2 [B]** Views render state and forward actions. Logic lives in `@Observable` models and services injected through `@Environment`. Add a dedicated model only when a screen's logic needs tests. Delete pass-through view models. No TCA, VIPER, coordinators or service locators.
- **R1.3 [B]** Each piece of state has exactly one owner. Derived state is computed. A mirror is reset wherever its owner resets.
- **R1.4 [N]** Put protocols only at IO and system boundaries (pasteboard, storage, clock, hotkeys, Accessibility, login items), so tests can use fakes.
- **R1.5 [B]** Add a third-party package only if it is pre-approved in CLAUDE.md Decisions or clearly better than writing the code. Its license must be GPL-3.0-compatible, and it needs an entry in THIRD_PARTY_NOTICES.md.
- **R1.6 [N]** Keep one primary type per file, and name the file after the type.

## R2. Concurrency
The project builds with Swift 6 and strict concurrency set to complete. The app target is MainActor by default; SPM packages are nonisolated by default.
- **R2.1 [B]** New code has no GCD, Combine or completion handlers. The one exception is deferring work to the next runloop pass for AppKit: mark it `// swiftlint:disable:next no_dispatch_queue` with a reason.
- **R2.2 [B]** Never block the main actor with IO, hashing, image decoding, OCR or database queries. Move that work to `@concurrent` functions or to an actor that is not the main actor.
- **R2.3 [B]** Prefer structured concurrency: `async let` and task groups. No `Task {}` in loops or inside async functions. `Task.detached` needs a written reason.
- **R2.4 [B]** `@unchecked Sendable`, `nonisolated(unsafe)` and `@preconcurrency` each need a comment stating the invariant. Use `Mutex` for short synchronous sections. Never hold a lock across `await`, and never use semaphores.
- **R2.5 [B]** Tie view work to `.task` or `.task(id:)`. Check for cancellation in long loops. Never swallow `CancellationError`. Resume every continuation exactly once.
- **R2.6 [N]** Use actors only for shared mutable state that is not UI.

## R3. SwiftUI
- **R3.1 [B]** Use Observation (`@Observable`, `@State`, `@Bindable`, `@Environment(Type.self)`). Never use `ObservableObject`, `@Published`, `@StateObject` or `@EnvironmentObject`.
- **R3.2 [B]** `@State` is `private` and initialized in exactly one place. It never copies a value passed in by the parent view.
- **R3.3 [B]** `body` does no work: no sorting, filtering or formatter creation. No `AnyView`, and no `.if()` modifier.
- **R3.4 [B]** `ForEach`, `List` and `Table` use stable `Identifiable` ids, never indices.
- **R3.5 [N]** Extract subviews as `View` structs, not computed `some View`. Pass rows their element. Keep closures and fast-changing values out of the environment.
- **R3.6 [N]** Use current APIs: `foregroundStyle`, `clipShape(.rect(cornerRadius:))`, `onChange` with two parameters, `.animation(_:value:)`, and `#Preview` with mock data.

## R4. AppKit
- **R4.1 [B]** Use AppKit only for a gap you can name: `NSPanel`, global hotkeys, `NSPasteboard`, the text system, event monitors. SwiftUI stays the source of truth.
- **R4.2 [B]** AppKit code runs on the main actor. Never store an `NSWindow` or `NSView` in a global.
- **R4.3 [N]** Choose the smallest bridge that works, in this order: pure SwiftUI, then `NSViewRepresentable`, then `NSViewControllerRepresentable`, then direct window or responder hooks.

## R5. Native look
[docs/design.md](../../docs/design.md) is the source of truth for screens. Load the `macos-native-ui` skill before UI work.
- **R5.1 [B]** Liquid Glass belongs only on the control layer: toolbars, the shelf container, floating controls. Content is never glass. Group custom glass in `GlassEffectContainer`, and apply `.glassEffect` last.
- **R5.2 [B]** Use system controls, SF Symbols, semantic colors and system text styles. Hardcoded colors, font sizes, spacing and radii are allowed only in `DesignSystem`.
- **R5.3 [B]** Every action can be done from the keyboard. Repeatable actions are menu commands with shortcuts. Icon-only controls carry a text label (`Button("…", systemImage:)`). Use no `onTapGesture` for actions.
- **R5.4 [B]** Every user-facing string goes through the String Catalog. Format dates and numbers with `FormatStyle`.
- **R5.5 [N]** Honor Reduce Motion, Reduce Transparency, Increase Contrast and Differentiate Without Color.
- **R5.6 [B]** A UI role listed in [docs/design.md › Components](../../docs/design.md#components) uses the component listed there. Screens never hand-assemble an equivalent from modifiers. A new recurring role gets a component and a row there first.

## R6. Errors
- **R6.1 [B]** Show errors from user actions in the UI. Never swallow them.
- **R6.2 [B]** No `!` force unwraps and no `try!`. For a proven invariant, use `guard` with `fatalError("<why>")`.

## R7. Privacy
- **R7.1 [B]** Clipboard contents, file names, URLs, window titles and other user data must never reach logs, crash reports, test fixtures or the network, and are never persisted outside the store. This holds even with `privacy: .private`.
- **R7.2 [B]** Use one `Logger(subsystem:category:)` per feature. Never use `print` or `NSLog`. Mark only ids, counts and enum states `.public`.
- **R7.3 [B]** Make no network calls beyond the ones CLAUDE.md Decisions allow. Commit no secrets.

## R8. Tests
- **R8.1 [B]** Every bug fix comes with a test that fails without the fix. New logic in models and services comes with tests.
- **R8.2 [B]** Write unit tests with Swift Testing (`@Test`, `#expect`, `#require`). Use XCTest only for UI tests (see docs/architecture.md). Tests are parallel-safe and share no state. Test through model seams and fakes, never a live pasteboard, `NSStatusBar` or a TCC prompt.
- **R8.3 [N]** Parameterize tests instead of duplicating them. Write `#expect(x == false)`, not `#expect(!x)`.

## R9. Scope and style
- **R9.1 [B]** Make the smallest change that solves the task. No unrelated refactors, renames or reformatting.
- **R9.2 [B]** Never copy strings, assets or names from Paste or any other proprietary app (CLAUDE.md, "IP rules").
- **R9.3 [N]** Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/): name things by role, use `sort`/`sorted` naming pairs, and name booleans as assertions.
- **R9.4 [N]** No comments by default. Add one only where a reader would otherwise introduce a bug.

## Do NOT flag
- Formatting and anything SwiftFormat or SwiftLint enforces. CI runs both.
- Code the diff did not touch, including any deprecated APIs in it.
- Speculative edge cases with no concrete path (file:line) that triggers them.
- Performance claims nobody measured.
- Personal style preferences that no rule above covers.

## Checklist
Walk this before calling a change done, and before every review verdict.
1. R0.2: it builds, the tests pass and lint is clean.
2. Each new or changed line passes R0–R9.
3. Behaviour matches docs/product.md, and UI matches docs/design.md. A deliberate change updates the doc in the same diff.
4. UI changes were run in the app, in light and dark mode, using only the keyboard (`macos-native-ui` → Verify).
5. A bug fix has a test that fails without the fix.

Report format:
```
VERDICT: PASS | FAIL
Blocking:
- path/File.swift:42 — R2.3 — <why> — fix: <concrete change>
Suggestions:
- path/File.swift:10 — R3.5 — ...
Checked: build ✓/✗/n.a., tests ✓/✗/n.a., lint ✓/✗, UI run ✓/✗/n.a.
```
