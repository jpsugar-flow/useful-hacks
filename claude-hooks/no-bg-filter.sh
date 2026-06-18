#!/bin/bash
# PreToolUse(Bash) hook: discourage patterns that are unnecessary because the
# Bash tool already handles them natively.
#
# Check 1 — no line-filters on background commands:
#   Background commands capture full stdout+stderr to a buffer; filtering before
#   capture means a wrong filter forces a full re-run of a slow command.
#   Applied only when run_in_background == true.
#
# Check 2 — no redundant stderr redirect or exit-code echo on any command:
#   The tool merges stdout and stderr automatically and reports the exit code in
#   the result/notification. Patterns like `2>&1` and
#   `echo "EXIT=${PIPESTATUS[0]:-$?}"` are therefore noise.
#   Applied to all commands.
#
# Escape hatch: include `# keep-filter` to bypass check 1, `# keep-boilerplate`
# to bypass check 2.
#
# Input (stdin JSON): { tool_input: { command, run_in_background }, ... }
# Output: hookSpecificOutput JSON on stdout, exit 0.
set -euo pipefail

input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input")
background=$(jq -r '.tool_input.run_in_background // false' <<<"$input")

[[ "$background" == "true" ]] || exit 0

# ------------------------------------------------------------------
# Check 1: redundant stderr redirect or exit-code echo
# ------------------------------------------------------------------
case "$command" in
  *"# keep-boilerplate"*) ;;
  *)
    if echo "$command" | grep -Eiq '2>&1|echo[[:space:]]+"?EXIT=\$(\{PIPESTATUS|\?)'; then
      jq -n '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: "Command contains redundant boilerplate (`2>&1` and/or `echo EXIT=...`). The Bash tool already merges stdout and stderr into one stream and reports the exit code in the tool result / notification — no manual capture is needed. The expected response to this message is to RE-ISSUE THE COMMAND WITH THE BOILERPLATE REMOVED, not to bypass the check. If you added `2>&1` so a downstream filter (`| tail`, `| grep`, ...) could see stderr, that is not a reason to keep it: remove the filter too and read the full tool result (use run_in_background for slow commands). Keep the boilerplate and bypass this check by appending `# keep-boilerplate` ONLY if the redirect produces behavior the tool cannot replicate — e.g. the streams must go to different files, or stderr must be piped inline into a program that transforms it (not merely truncates or filters it). \"The command works as written\" is not a justification."
        }
      }'
      exit 0
    fi
    ;;
esac

# ------------------------------------------------------------------
# Check 2: piping output through a line-dropping filter
# ------------------------------------------------------------------
case "$command" in
  *"# keep-filter"*) exit 0 ;;
esac

pipeline=${command//||/}
filters='grep|egrep|fgrep|rg|ag|ack|sed|awk|head|tail|cut'
if ! grep -Eq "\|&?[[:space:]]*($filters)\b" <<<"$pipeline"; then
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Background command pipes its output through a line filter. Re-run it in the background WITHOUT the inline filter: the full output is captured to a buffer you can read and search afterward, so a wrong filter never forces a re-run of this (slow) command. Keep the filter and bypass this check by re-running the same command with a `# keep-filter` comment appended ONLY if: (a) the unfiltered output would be unreasonably large to capture, or (b) this check misfired and the filter is essential or not actually dropping needed lines."
  }
}'
exit 0
