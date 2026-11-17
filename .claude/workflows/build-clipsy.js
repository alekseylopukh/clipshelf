export const meta = {
  name: 'build-clipsy',
  description: 'Implement docs/roadmap.md task by task: implement, independent review, fix, gated commit; then push a branch and open one PR',
  whenToUse: 'The maintainer asks to build Clipsy (or a range of roadmap tasks) autonomously.',
  phases: [
    { title: 'Plan', detail: 'prepare the branch and list pending roadmap tasks' },
    { title: 'Build', detail: 'per task: implement, review until PASS, commit through the gate' },
    { title: 'Ship', detail: 'push the branch and open or refresh one PR with all human checks' },
  ],
}

// args (all optional): { from: 'T1.3', to: 'T6.6', branch: 'build/roadmap', maxTasks: 10, maxReviewRounds: 3, openPR: true }
// maxReviewRounds counts reviews: 3 means up to 3 reviews and 2 fix rounds.
const opts = Object.assign(
  { from: null, to: null, branch: 'build/roadmap', maxTasks: 1000, maxReviewRounds: 3, openPR: true },
  args || {},
)

if (!opts.branch || /^(main|master)$/.test(opts.branch)) {
  return { stopped: 'plan', problem: `branch "${opts.branch}" is not allowed; the workflow never works on main` }
}

const COMMON = `You work in the Clipsy git repository in the current working directory (run \`cd "$(git rev-parse --show-toplevel)"\` first). Follow CLAUDE.md and .claude/rules/code-rules.md exactly.`

const GH = `Use the GitHub CLI as the account that owns the origin repository: read the owner from \`git remote get-url origin\`, and if \`gh auth status\` lists several accounts run gh with \`GH_TOKEN=$(gh auth token -u <owner>)\`.`

const PLAN = {
  type: 'object',
  properties: {
    ok: { type: 'boolean' },
    problem: { type: 'string' },
    tasks: {
      type: 'array',
      items: {
        type: 'object',
        properties: { id: { type: 'string' }, title: { type: 'string' } },
        required: ['id', 'title'],
      },
    },
  },
  required: ['ok', 'tasks'],
}

const WORK = {
  type: 'object',
  properties: {
    status: { type: 'string', enum: ['staged', 'blocked'] },
    summary: { type: 'string' },
    blockedReason: { type: 'string' },
    commitTitle: { type: 'string' },
    checks: { type: 'string' },
    humanChecks: { type: 'array', items: { type: 'string' } },
  },
  required: ['status', 'summary'],
}

const VERDICT = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASS', 'FAIL'] },
    tree: { type: 'string' },
    report: { type: 'string' },
  },
  required: ['verdict', 'tree', 'report'],
}

const COMMIT = {
  type: 'object',
  properties: {
    ok: { type: 'boolean' },
    sha: { type: 'string' },
    problem: { type: 'string' },
  },
  required: ['ok'],
}

const SHIP = {
  type: 'object',
  properties: { ok: { type: 'boolean' }, prUrl: { type: 'string' }, problem: { type: 'string' } },
  required: ['ok'],
}

phase('Plan')
const plan = await agent(
  `${COMMON}

Prepare the branch and list the work. Change no tracked files.
1. If \`git status --porcelain\` is not empty, stop: ok=false, problem = the list. Never stash or discard anything.
2. Run \`git fetch origin\`.
3. Branch "${opts.branch}":
   - if it does not exist locally, run \`git switch -c ${opts.branch} origin/main\`;
   - if \`git log origin/main..${opts.branch}\` is empty, run \`git switch -C ${opts.branch} origin/main\`;
   - if \`git merge-base --is-ancestor origin/main ${opts.branch}\` succeeds, run \`git switch ${opts.branch}\` (work in progress on the current base);
   - otherwise the branch may have been squash-merged. It counts as merged only if every commit in \`git log origin/main..${opts.branch}\` has a "Roadmap: T…" line and every one of those tasks has "- Status: done" in \`git show origin/main:docs/roadmap.md\`; then run \`git switch -C ${opts.branch} origin/main\`. Otherwise stop: ok=false, problem = "branch ${opts.branch} has unmerged work on an outdated base: <commits without a Roadmap line or with tasks not done on main>; merge its PR or rebase it first".
4. Read docs/roadmap.md on that branch. Every task is a heading "### T<m>.<n> <title>". A task is done when its section has a line "- Status: done", or its milestone heading ends with "done".
5. Return the tasks that are not done, in roadmap order${opts.from ? `, starting at ${opts.from}` : ''}${opts.to ? `, ending at ${opts.to} inclusive` : ''}.`,
  { label: 'plan', phase: 'Plan', schema: PLAN },
)

if (!plan || !plan.ok) {
  return { stopped: 'plan', problem: plan ? plan.problem : 'planner failed' }
}

const tasks = plan.tasks.slice(0, opts.maxTasks)
if (plan.tasks.length > tasks.length) {
  log(`maxTasks=${opts.maxTasks}: ${plan.tasks.length - tasks.length} pending tasks left for a later run`)
}
log(`${tasks.length} pending tasks on ${opts.branch}`)

const review = (task, work, round) =>
  agent(
    `Review the staged change in the git repository in the current working directory (\`git diff --cached\`, read-only).
Goal: roadmap task ${task.id} "${task.title}" in docs/roadmap.md. Check its Deliverable and Acceptance as well as the rules. The change must also add "- Status: done" to that task's section.
Checks the author reports: ${work.checks || 'not reported'}.
Return the verdict, \`git write-tree\` output as tree, and the full report in the code-rules.md format (it starts with "VERDICT:").`,
    { label: `review ${task.id} #${round}`, phase: 'Build', agentType: 'swift-reviewer', schema: VERDICT },
  )

const passed = (v) => v && v.verdict === 'PASS' && /^VERDICT:\s*PASS\b/m.test(v.report || '')

phase('Build')
const done = []
let stopped = null

for (const task of tasks) {
  const tag = `${task.id} ${task.title}`
  let work = await agent(
    `${COMMON}

Implement roadmap task ${task.id} ("${task.title}") on branch ${opts.branch}.
- Read the task in docs/roadmap.md and every doc section its "Spec" field links. The docs win over the roadmap.
- If the task needs a decision the docs leave to the maintainer (the roadmap's "Needs the maintainer" list) or a secret, change nothing and return status "blocked" with the reason.
- Load the skills the work needs: macos-native-ui for any UI, swift-concurrency for isolation work, swift-testing-pro for tests, swiftui-expert-skill or swiftui-pro for SwiftUI.
- Implement the Deliverable. Meet every Acceptance point and the "Rules for every task" in the roadmap.
- In docs/roadmap.md, add the line "- Status: done" as the last field of this task's section.
- Verify: \`scripts/build.sh\`, \`scripts/build.sh test\`, \`scripts/lint.sh\`. Fix until all pass. For UI work, build and launch the app and check what the task describes.
- Stage exactly this task's files with \`git add <paths>\`. Leave no unstaged or untracked leftovers. Do NOT commit and do NOT run approve.sh.
Return: status "staged", a summary, a Conventional Commit title, the checks you ran with results, and the task's "Human check" items (if any) as humanChecks.`,
    { label: `implement ${task.id}`, phase: 'Build', schema: WORK },
  )

  if (!work || work.status === 'blocked') {
    stopped = { task: tag, reason: work ? work.blockedReason || work.summary : 'implementer failed' }
    break
  }

  let verdict = null
  for (let round = 1; round <= opts.maxReviewRounds; round++) {
    verdict = await review(task, work, round)
    if (!verdict) verdict = await review(task, work, `${round}b`)
    if (passed(verdict) || round === opts.maxReviewRounds || !verdict) break
    const fixed = await agent(
      `${COMMON}

The independent review of roadmap task ${task.id} ("${task.title}") failed. The staged change is in the index.
Fix every blocking finding below, re-run \`scripts/build.sh\`, \`scripts/build.sh test\` and \`scripts/lint.sh\`, and restage exactly the task's files with no leftovers. Do not commit. If a finding is wrong, leave the code and explain why in the summary.
Return humanChecks only for checks that are new since the original implementation.

Review report:
${verdict.report}`,
      { label: `fix ${task.id} #${round}`, phase: 'Build', schema: WORK },
    )
    if (!fixed || fixed.status === 'blocked') {
      stopped = { task: tag, reason: fixed ? fixed.blockedReason || fixed.summary : 'fixer failed' }
      break
    }
    // keep the implementer's commit title and human checks unless the fixer adds to them
    work = Object.assign({}, work, fixed, {
      humanChecks: [...new Set([...(work.humanChecks || []), ...(fixed.humanChecks || [])])],
    })
  }
  if (stopped) break

  if (!passed(verdict)) {
    stopped = { task: tag, reason: 'review did not pass', report: verdict ? verdict.report : 'no review' }
    break
  }

  const message = [
    work.commitTitle || `feat: ${task.title}`,
    '',
    `Roadmap: ${task.id}`,
    ...(work.humanChecks || []).map((c) => `Human check: ${c.replace(/\n/g, ' ')}`),
    '',
    'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>',
  ].join('\n')

  const commit = await agent(
    `In the git repository in the current working directory, the staged change for roadmap task ${task.id} passed review on tree ${verdict.tree}. Do exactly this:
1. Run \`git write-tree\`. If it is not ${verdict.tree}, stop: ok=false, problem="staged tree changed after review". If \`git status --porcelain\` lists anything besides staged changes (unstaged or untracked files), stop: ok=false, problem="leftovers outside the staged change" plus the list. Do not touch the index.
2. Run \`.claude/skills/pre-commit-review/scripts/approve.sh\`.
3. Commit with a quoted heredoc so nothing is expanded, exactly:
git commit -F - <<'CLIPSY_MSG'
${message}
CLIPSY_MSG
4. Return ok and the new commit sha. If the commit gate or the git hook blocks the commit, return ok=false with its output.`,
    { label: `commit ${task.id}`, phase: 'Build', schema: COMMIT },
  )
  if (!commit || !commit.ok) {
    stopped = { task: tag, reason: 'commit failed', detail: commit ? commit.problem : null }
    break
  }

  done.push({ task: tag, sha: commit.sha })
  log(`done ${tag} (${done.length}/${tasks.length})`)
}

let pr = null
if (opts.openPR && done.length > 0) {
  phase('Ship')
  pr = await agent(
    `In the git repository in the current working directory, on branch ${opts.branch}:
1. Push with \`git push -u origin ${opts.branch}\`. Never push main and never force-push.
2. Build the PR description from the whole branch, not just this run: read \`git log origin/main..HEAD --reverse --format=%B%x00\`. For every commit, take its title, its "Roadmap: T…" line and its "Human check: …" lines.
3. ${GH} If a PR from ${opts.branch} to main is open, replace its title and body; otherwise open one.
Title: "feat: roadmap <first task id>–<last task id>" over all tasks on the branch.
Body, in this order:
- "## Tasks": one line per commit: "- <Roadmap id>: <commit title>".
- "## Status": ${stopped ? `"stopped at ${stopped.task}: ${String(stopped.reason).replace(/"/g, "'")}"` : '"all requested tasks are done"'}.
- "## Human checks": a task-list checklist "- [ ] <task id>: <check>" for every Human check line. Keep any boxes already ticked in the existing body.
- One "Roadmap: <id>" line per task, so the squash commit records what was done.
- "AI assistance: built by the build-clipsy workflow with Claude Code."
- "🤖 Generated with [Claude Code](https://claude.com/claude-code)"
Return ok and the PR URL.`,
    { label: 'ship', phase: 'Ship', schema: SHIP },
  )
}

return { branch: opts.branch, done, stopped, pr }
