# Code standards

These are the coding rules for everyone who writes code for Clipshelf, human or AI. The pre-commit review checks every change against them ([review-checklist.md](review-checklist.md)). [CLAUDE.md](../../CLAUDE.md) imports this file, so agents always have it loaded.

The rules are distilled from published Swift agent skills by Antoine van der Lee and Paul Hudson (the full skills are vendored in `.claude/skills/`), from production macOS apps (CodexBar, IceCubes, alt-tab-macos, NetNewsWire), from Apple's Liquid Glass guidance and HIG, and from the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).

## Toolchain and project settings

- Target macOS 26 or later. Gate APIs that need macOS 27 with `#available`.
- Use the Swift 6 language mode with strict concurrency set to complete.
- The app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Local SPM packages are nonisolated by default. Check which of the two applies before you reason about isolation.
- Treat warnings as errors in CI. A change that adds a warning is not done.
- Before you use an API newer than your training data, check that it exists and when it became available. Use the Xcode MCP `DocumentationSearch` tool or Apple's documentation. Never invent API names.

## Architecture

- **Modules.** Organize code as local SPM packages by feature and layer. The module list and allowed dependencies live in [architecture.md](../architecture.md); design constants and shared components go in `DesignSystem`. The app target stays thin: it only wires dependencies and declares scenes. Lower layers never import higher ones, and UI modules never import storage internals.
- **Models and views.** Views read `@Observable` models and services injected through `@Environment`. Do not create a view model for every view. Add a dedicated model only when a screen has non-trivial logic that needs unit tests. Delete view models that only pass properties through.
- **No heavyweight frameworks.** No TCA, VIPER, coordinators or service locators.
- **Data flow.** State flows down and actions flow up. Each piece of state has exactly one owner. Derived state is computed, not mirrored. If you must mirror, reset the copy wherever the owner resets.
- **Protocols only at IO and system boundaries.** Examples are the pasteboard, storage, clock, hotkeys, Accessibility and launch at login. These protocols exist so tests can use fakes. Do not put a protocol in front of every type.
- **Files.** One primary type per file. Small private helper types may share it. Name files after the type they hold.
- **Dependencies.** Prefer Apple frameworks. Do not add a third-party package without the maintainer's approval. Its license must be GPL-3.0-compatible, and it gets an entry in [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).

## Concurrency

- Use async/await only. New code has no GCD, Combine or completion handlers. The one exception is deferring work to the next runloop pass for AppKit or Core Animation. Mark it with `// swiftlint:disable:next no_dispatch_queue` plus a one-line reason.
- `async` does not mean "off the main thread". Put CPU-heavy work (hashing, OCR, thumbnails, search indexing) in `@concurrent` functions, or behind an actor that is not the main actor.
- Prefer structured concurrency: `async let` for a fixed number of tasks, task groups for a dynamic number. Never create `Task {}` inside a loop or inside an async function. `Task.detached` needs a written reason.
- Use an actor only for shared mutable state that is not UI state and cannot live on the main actor. Every `await` is a reentrancy point: re-check state after it.
- `@unchecked Sendable`, `nonisolated(unsafe)` and `@preconcurrency` each need a comment that states the invariant. For short synchronous critical sections, use `Mutex` from Synchronization. Never hold a lock across `await`, and never use semaphores in async code.
- Respect cancellation. Tie work to a view with `.task` or `.task(id:)`. Call `try Task.checkCancellation()` in long loops. Never swallow `CancellationError`.
- Resume every continuation exactly once. Give every `AsyncStream` an explicit buffering policy.
- Satisfy protocols on main-actor types with isolated conformances (`extension Foo: @MainActor Bar`).

## SwiftUI

- Use Observation: `@Observable`, `@State` for ownership, `@Bindable` and `@Environment(Type.self)` to pass models down. Never use `ObservableObject`, `@Published`, `@StateObject` or `@EnvironmentObject`.
- `@State` is always `private` and initialized in exactly one place. Never copy a parent's input into `@State`.
- `body` does no work. Do not sort, filter, format or create formatters there. Do not use `AnyView` or an `.if()` modifier. Put conditions inside modifiers instead.
- Extract subviews as `View` structs, not as computed properties or methods that return `some View`. Pass a row its element, not the whole store. Button actions call methods.
- Give `ForEach`, `List` and `Table` stable `Identifiable` identity. Never use indices or ids derived from editable fields.
- Use `@Entry` environment values with stable defaults. Do not put closures or fast-changing values in the environment.
- Previews use `#Preview` with in-memory mock data. They make no network calls and start no live services.
- Use current APIs: `foregroundStyle`, `clipShape(.rect(cornerRadius:))`, `onChange` with two parameters, `.animation(_:value:)`, `Task.sleep(for:)` and `FormatStyle` (never `String(format:)`). Match user search input with `localizedStandardContains`.
- Mark deprecated APIs found while working on a feature, but do not rewrite them in that change. List them separately.

## AppKit interop

- Start with SwiftUI. Drop to AppKit only for a gap you can name: a non-activating `NSPanel`, global hotkeys, `NSPasteboard`, the text system, the responder chain or event monitors.
- Choose the smallest bridge that works, in this order: pure SwiftUI, then `NSViewRepresentable`, then `NSViewControllerRepresentable`, then direct `NSWindow` or responder hooks. SwiftUI stays the source of truth. Coordinators only translate; they are not a second architecture.
- All AppKit code runs on the main actor. Never store `NSWindow` or `NSView` in globals.
- Many AppKit calls are synchronous XPC and can block the main thread. Keep them off hot paths.

## Native look

Before building or changing any UI, load the `macos-native-ui` skill. It holds the detailed rules, and [docs/design.md](../design.md) is the source of truth for our screens. The short version:

- Use system controls, `Label`, SF Symbols, semantic styles (`.secondary`, `.tint`) and system text styles. Do not hardcode colors, font sizes, paddings or corner radii outside the design-constants type.
- Liquid Glass belongs in the control layer, never on content. Let system components provide it. Write a custom `glassEffect` only for floating controls, grouped in a `GlassEffectContainer`.
- Every repeatable action is a menu command with a keyboard shortcut. The app works fully from the keyboard.
- Test light mode, dark mode, Reduce Transparency, Increase Contrast and Reduce Motion.

## Errors

- Show errors from user actions in the UI, as an alert or an inline state. Never swallow them.
- No force unwrapping and no `try!`. For a proven invariant, use `guard` plus `fatalError("<why this cannot happen>")`.
- Use typed throws only when the set of errors is closed.

## Logging and privacy

- Create one `Logger(subsystem: <bundle id>, category: <feature>)` per feature. Never use `print`, `debugPrint`, `dump` or `NSLog`; SwiftLint blocks them.
- **Never log clipboard contents, file names, URLs, window titles or any user data, not even with `privacy: .private`.** Use `privacy: .public` only for ids, counts and enum states.
- Do not build log messages into a `String` ahead of time. Interpolate directly into the `Logger` call.
- Commit no secrets: no certificates, no notarization credentials, no `.env` files.

## Performance

- Use lazy stacks, `List` or `Table` for large collections, with stable ids.
- Do not claim one approach is faster without measuring it. Use Instruments (SwiftUI, Hangs, Time Profiler); the `swiftui-expert-skill` has trace tooling.
- Keep the main thread free of IO, hashing, image decoding and database queries.

## Accessibility and localization

- Icon-only buttons and menus still carry text, for example `Button("Delete", systemImage: "trash")`. Never use `onTapGesture` for an action.
- Give custom rows and cards VoiceOver labels and actions. Honor Reduce Motion and Differentiate Without Color.
- Every user-facing string lives in the String Catalog. Use `Text("...")` literals in SwiftUI and `String(localized:)` elsewhere. Never use `NSLocalizedString`.
- Format dates, numbers and lists with `FormatStyle`.

## Testing

- Write unit tests with Swift Testing (`@Test`, `#expect`, `#require`). Use structs for suites and `init` for setup. Parameterize instead of duplicating tests. Write `#expect(x == false)`, not `#expect(!x)`.
- Tests run in parallel and in random order, so they share no state.
- Test through model seams and protocol fakes, not through a live `NSStatusBar`, `NSMenu` or the real pasteboard. Tests never trigger Keychain or privacy (TCC) prompts.
- Every bug fix comes with a test that fails without the fix. Passing unit tests alone do not prove a UI bug is fixed: check it in the running app.

## Style

- Formatting is SwiftFormat's job and linting is SwiftLint's (`.swiftformat`, `.swiftlint.yml`). In Claude Code, a hook formats each edited Swift file. `scripts/lint.sh` must pass before a commit.
- Follow the Swift API Design Guidelines. Aim for clarity at the point of use. Name things by role. Non-mutating methods read as nouns and mutating ones as verbs (`sorted` and `sort`). Booleans read as assertions (`isPinned`).
- Write no comments by default. Add one only where a reader would otherwise introduce a bug. Keep it to one short lowercase line. No doc comments on private members.
- Make the smallest change that solves the task. Do not reformat, rename or modernize code you were not asked to touch.
