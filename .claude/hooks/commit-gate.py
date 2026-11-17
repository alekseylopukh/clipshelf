#!/usr/bin/env python3
# blocks git commit unless pre-commit-review approved the exact staged tree
import json
import os
import re
import shlex
import subprocess
import sys
from typing import NoReturn

SEPARATORS = {";", "&&", "||", "|", "&", "(", ")", "\n"}
PREFIXES = {"env", "command", "exec", "nohup", "time", "sudo"}
GIT_OPTS_WITH_ARG = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--super-prefix", "--config-env"}
COMMIT_OPTS_WITH_ARG = {
    "-m", "--message", "-F", "--file", "-C", "--reuse-message", "-c", "--reedit-message",
    "-t", "--template", "--author", "--date", "--fixup", "--squash", "--cleanup", "--trailer",
}
SHORT_WITH_ARG = set("mFCct")
SHORT_WITH_ATTACHED_ARG = set("uS")
FORBIDDEN_SHORT = {"a": "-a", "n": "--no-verify", "o": "--only", "i": "--include", "p": "--patch"}
FORBIDDEN_LONG = {"--all", "--no-verify", "--only", "--include", "--pathspec-from-file", "--interactive", "--patch"}


def block(reason) -> NoReturn:
    print(f"Commit blocked: {reason}", file=sys.stderr)
    sys.exit(2)


def long_match(name, options):
    # git accepts any unambiguous prefix of a long option
    return len(name) > 2 and any(opt.startswith(name) for opt in options)


def tokenize(command):
    lexer = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    return list(lexer)


def commit_invocations(tokens):
    at_start = True
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok in SEPARATORS:
            at_start = True
            i += 1
            continue
        if at_start and ("=" in tok and not tok.startswith("-") or tok in PREFIXES):
            i += 1
            continue
        if at_start and os.path.basename(tok) == "git":
            git_dir_arg = None
            j = i + 1
            while j < len(tokens) and tokens[j].startswith("-"):
                opt = tokens[j]
                if opt.split("=", 1)[0] in {"--git-dir", "--work-tree"}:
                    block("'--git-dir' and '--work-tree' are not supported by the commit gate; run git from inside the repository.")
                if opt in GIT_OPTS_WITH_ARG:
                    if opt == "-C" and j + 1 < len(tokens):
                        git_dir_arg = tokens[j + 1]
                    j += 2
                else:
                    j += 1
            if j < len(tokens) and tokens[j] == "commit":
                k = j + 1
                args = []
                while k < len(tokens) and tokens[k] not in SEPARATORS and not tokens[k].startswith(("<", ">")):
                    args.append(tokens[k])
                    k += 1
                yield git_dir_arg, args
                i = k
                at_start = False
                continue
        at_start = False
        i += 1


def check_args(args):
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--":
            if i + 1 < len(args):
                block("committing paths directly ('git commit <path>') bypasses the reviewed index. Stage with 'git add' instead.")
            break
        if arg.startswith("--"):
            name = arg.split("=", 1)[0]
            if long_match(name, FORBIDDEN_LONG):
                block(f"'{name}' is not allowed. Stage files with 'git add', run the pre-commit-review skill, then commit.")
            if long_match(name, {o for o in COMMIT_OPTS_WITH_ARG if o.startswith("--")}) and "=" not in arg:
                i += 1
        elif arg.startswith("-") and len(arg) > 1:
            for pos, ch in enumerate(arg[1:]):
                if ch in SHORT_WITH_ATTACHED_ARG:
                    break
                if ch in FORBIDDEN_SHORT:
                    block(f"'{FORBIDDEN_SHORT[ch]}' is not allowed. Stage files with 'git add', run the pre-commit-review skill, then commit.")
                if ch in SHORT_WITH_ARG:
                    if pos == len(arg) - 2:
                        i += 1
                    break
        else:
            block("committing paths directly ('git commit <path>') bypasses the reviewed index. Stage with 'git add' instead.")
        i += 1


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        block("could not parse the hook payload.")
    command = (payload.get("tool_input") or {}).get("command") or ""
    if not re.search(r"\bgit\b", command) or "commit" not in command:
        sys.exit(0)
    if re.search(r"(\b(bash|sh|zsh)\s+-\w*c\b|\beval\b)", command):
        block("run 'git commit' directly, not through 'bash -c', 'sh -c' or 'eval'.")
    try:
        tokens = tokenize(command)
    except ValueError:
        block("could not parse the command; run 'git commit' as a plain command.")

    cwd = payload.get("cwd") or os.getcwd()
    for git_dir_arg, args in commit_invocations(tokens):
        check_args(args)
        repo = os.path.join(cwd, git_dir_arg) if git_dir_arg else cwd
        try:
            tree = subprocess.run(["git", "-C", repo, "write-tree"], capture_output=True, text=True, check=True).stdout.strip()
            git_dir = subprocess.run(
                ["git", "-C", repo, "rev-parse", "--absolute-git-dir"], capture_output=True, text=True, check=True
            ).stdout.strip()
        except (OSError, subprocess.CalledProcessError):
            block("could not read the staged tree.")
        if not os.path.isfile(os.path.join(git_dir, "review-passed", tree)):
            block(
                f"the staged changes have not passed review (tree {tree}). Run the pre-commit-review skill on exactly "
                "what is staged; it approves the tree only when there are no blocking findings."
            )
    sys.exit(0)


main()
