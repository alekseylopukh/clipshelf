# Review checklist

The pre-commit review (`.claude/skills/pre-commit-review`) and human reviewers use this list. Every item points back to a rule in [code-standards.md](code-standards.md), and that file wins if the two disagree.

Report only real problems. Each finding has a location (`file:line`), the rule it breaks, why it matters and a concrete fix.

## Blocking

Any one of these fails the review.

- **Build and tests.** The project does not build, a test fails or a new warning appears.
- **Lint.** `scripts/lint.sh --staged` fails.
- **Correctness.** The change can produce wrong behaviour. Examples: a logic error, an unhandled edge case on a real path, a state mirror that is not reset when its owner resets, or a broken migration.
- **Concurrency.**
  - A data race or an isolation violation.
  - A continuation that is not resumed exactly once.
  - A `Task {}` in a loop, or an unstructured task where structured concurrency fits.
  - A swallowed `CancellationError`.
  - `@unchecked Sendable`, `nonisolated(unsafe)` or `@preconcurrency` without an invariant comment.
  - Blocking work on the main actor, such as IO, hashing, image decoding or a database query.
  - GCD in new code without a documented runloop reason.
- **Privacy.**
  - Clipboard contents, file names, URLs or other user data reach logs, crash reports, test fixtures or the network.
  - A new network call that the Decisions in CLAUDE.md do not allow.
  - A committed secret.
- **Architecture.**
  - A module imports a higher layer.
  - A view owns business logic that belongs in a model or service.
  - A second source of truth for one piece of state.
  - A new third-party dependency without approval or without a notice entry.
- **SwiftUI.**
  - `ObservableObject`, `@Published`, `@StateObject` or `@EnvironmentObject`.
  - `@State` that is not private.
  - Work inside `body`.
  - `AnyView`, or an `.if()` modifier.
  - Unstable `ForEach` identity.
- **Native look.**
  - Liquid Glass on content.
  - A custom control where a system one exists.
  - A hardcoded color, font size or spacing outside the design-constants type.
  - An action with no keyboard path.
  - An icon-only control with no text label.
- **Errors.**
  - A force unwrap or `try!` without a proven invariant.
  - An error from a user action that is swallowed instead of shown.
- **Tests.** A bug fix without a test that fails without the fix. New logic in a model or service without tests.
- **IP.** Strings, assets or names copied from Paste or another proprietary app (see [CLAUDE.md](../../CLAUDE.md#ip-rules)).
- **Scope.** Unrelated refactors, reformatting or renames mixed into the change.

## Non-blocking

Report these as suggestions.

- Deprecated APIs in code the change did not touch.
- Naming that does not follow the Swift API Design Guidelines.
- A performance improvement you suspect but have not measured.
- A missing accessibility nicety beyond the basics listed above.

## Report format

```
VERDICT: PASS | FAIL
Blocking:
- path/File.swift:42 — <rule> — <why> — fix: <concrete change>
Suggestions:
- ...
Checked: build ✓/✗/n.a., tests ✓/✗/n.a., lint ✓/✗, UI run ✓/✗/n.a.
```
