---
name: pre-commit-review
description: Mandatory quality gate before every git commit in Clipshelf. Lints, builds, tests and reviews exactly the staged changes against .claude/rules/code-rules.md, then approves the staged tree only if nothing blocking is found. Use whenever you are about to commit; the commit hook refuses commits whose staged tree was not approved.
---

# Pre-commit review

The commit hook (`.claude/hooks/commit-gate.py`) blocks `git commit` until the staged tree has been approved by this procedure. Approval belongs to the exact staged snapshot. Any change to the staging area after approval requires a new review.

## Procedure

1. **Freeze the scope.** Stage exactly what will be committed with `git add <paths>`, then check it with `git diff --cached --stat`. If nothing is staged, stop.
2. **Lint.** Run `scripts/lint.sh --staged`. Fix every finding, restage, and start again from step 1.
3. **Build and test.** Do this once an Xcode project or `Package.swift` exists. Build, then run the tests of every module the change touches. Fix failures and start again from step 1. If the change touches UI, also follow the "Verify" section of the `macos-native-ui` skill. If it touches `.claude/hooks/`, run `scripts/test-commit-gate.sh` and add a case for the bug being fixed.
4. **Independent review.** Hand the staged diff to the `swift-reviewer` subagent (Agent tool, `subagent_type: swift-reviewer`). Pass along:
   - the task's goal in one or two sentences;
   - which checks from steps 2–3 ran and their results.

   The reviewer reads `git diff --cached` itself. Do not paste your own conclusions into the prompt; the point is an unanchored second opinion.
5. **Act on the verdict.**
   - **FAIL:** fix the blocking findings, then start again from step 1. Do not argue findings away. If a finding is wrong, explain why to the user and let them decide.
   - **PASS:** run `${CLAUDE_SKILL_DIR}/scripts/approve.sh`, then commit immediately without touching the staging area.
6. **Report** the verdict and any non-blocking suggestions to the user in one short list.

## Rules

- Never run `approve.sh` without a PASS from the reviewer on the current staged tree.
- Never bypass the gate. That means no `--no-verify`, no `-n`, no `git commit -a`, no editing the hook, and no writing the approval marker by hand.
- Docs-only changes still go through the reviewer. It checks IP leaks, broken links and contradictions with the "Where things live" table in CLAUDE.md.
