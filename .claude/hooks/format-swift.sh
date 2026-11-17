#!/bin/bash
f=$(jq -r '.tool_input.file_path // empty')
case "$f" in *.swift) ;; *) exit 0 ;; esac
command -v swiftformat >/dev/null || exit 0
swiftformat --quiet --config "${CLAUDE_PROJECT_DIR:-.}/.swiftformat" "$f" >/dev/null 2>&1
exit 0
