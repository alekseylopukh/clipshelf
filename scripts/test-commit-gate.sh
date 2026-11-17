#!/bin/bash
# table-driven tests for .claude/hooks/commit-gate.py; runs in a throwaway repo
set -uo pipefail
root=$(git rev-parse --show-toplevel)
gate="${GATE:-$root/.claude/hooks/commit-gate.py}"
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
git -C "$repo" init -q && printf 'a\n' > "$repo/a.txt" && git -C "$repo" add a.txt
fail=0

run() {
  local want=$1 cmd=$2
  printf '{"cwd":%s,"tool_input":{"command":%s}}' "$(jq -Rn --arg v "$repo" '$v')" "$(jq -Rn --arg v "$cmd" '$v')" \
    | python3 "$gate" >/dev/null 2>&1
  local got=$?
  if [ "$got" != "$want" ]; then
    echo "FAIL want=$want got=$got: $cmd"
    fail=1
  fi
}

# not approved: every commit is blocked, other commands pass
for c in 'git status' 'git log -n 3' 'echo "git commit"' 'git commit-tree abc' 'grep -r commit .'; do run 0 "$c"; done
for c in 'git commit -m x' 'git -c user.name=x commit -m x' 'git --no-pager commit -m x' '/usr/bin/git commit -m x' \
         'cd . && git commit -m x' 'FOO=1 git commit -m x' 'timeout 60 git commit -m x' 'env -i git commit -m x' \
         'sudo -u me git commit -m x'; do run 2 "$c"; done

# approved: plain commits pass, words inside messages do not trigger anything
tree=$(git -C "$repo" write-tree); mkdir -p "$repo/.git/review-passed"; touch "$repo/.git/review-passed/$tree"
for c in 'git commit -m x' 'git commit -m "add eval harness"' 'git commit -m "use sh -c in script"' \
         'git commit -m "drop -a and -n flags"' 'git log -n 3 && git commit -m x' 'git commit -sm x' \
         'git commit --amend --no-edit' 'git commit --mess "x y"' 'git commit -uno -m x' 'git commit --allow-empty -m x' \
         'git -C . commit -m x' \
         "git commit -m \"\$(cat <<'EOF'
feat: eval support, bash -c wrapper, -a and -n
EOF
)\"" \
         "cat > n.md <<EOF
can't commit
EOF" \
         "git commit -F - <<'EOF'
fix eval handling, use sh -c in script, don't break
EOF" \
         'git commit -m "use <<EOF in docs"' 'git commit -m "title

use <<EOF in docs"' 'git commit -m "flags = a << b"' \
         "git add a.txt && git commit -F - <<EOF
can't stop -a -n
EOF"; do run 0 "$c"; done

# approved but forbidden: flags that bypass the reviewed index or hooks, and indirect invocations
for c in 'git commit -am x' 'git commit -nm x' 'git commit -an -m x' 'git commit --no-verify -m x' 'git commit --no-veri -m x' \
         'git commit -m x f.txt' 'git commit -m x -- f' 'git commit -o -m x f' 'git commit --onl f -m x' \
         'git commit --include f -m x' 'git commit --incl -m x' 'git commit --pathspec-from-file=l -m x' \
         'git commit --pathspec-from=l -m x' 'git commit --interact' 'git commit -p' 'git --git-dir=/x/.git commit -m x' \
         'timeout 60 git commit --no-verify -m x' 'git commit -m "unterminated' \
         'bash -c "git commit -am x"' 'sh -c "git commit -m x"' 'zsh -lc "git commit -m x"' '/bin/bash -c "git commit"' \
         'bash -o pipefail -c "git commit -am x"' 'eval git commit -am x' 'eval "git commit -m x"' \
         'C="git commit -am x"; eval "$C"' 'C="git commit -am x"; bash -c "$C"' "xargs sh -c 'git commit -am x'" \
         'env -i bash -c "git commit -am x"' '/usr/bin/env bash -c "git commit -am x"' 'sudo -u me bash -c "git commit -am x"' \
         'timeout 60 bash -c "git commit -am x"' 'echo "git commit -am x" | bash' 'bash -c "echo hi" && git commit -m x' \
         'echo "git commit -am x" | env bash' 'echo "git commit -am x" | sudo -u me sh' 'echo "git commit -am x" | timeout 5 bash -s' \
         'bash -O extglob -c "git commit -am x"' 'bash --rcfile /dev/null -c "git commit -am x"' 'bash <<< "git commit -am x"' \
         'echo -am x | xargs git commit' 'tcsh -c "git commit -am x"' 'source run-commit.sh && git commit -m x' \
         'cat <<END-OF > f
x
END-OF
git commit -am x' 'cat <<EOF > f
never closed
git commit -am x'; do run 2 "$c"; done

# known limitations (not blocked): G=git; $G commit -am x, git aliases (git -c alias.ci="commit -a" ci).
# the gate stops accidental bypasses by a cooperating agent; it is not a sandbox.

[ "$fail" = 0 ] && echo "commit gate: all cases pass"
exit "$fail"
