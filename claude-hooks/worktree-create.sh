#!/bin/bash
# WorktreeCreate hook: create the worktree on a branch using JP's `jp/` prefix
# instead of Claude Code's default `worktree-` prefix.
#
# Input (stdin JSON): { session_id, transcript_path, cwd, hook_event_name, name }
#   - name: the worktree name requested (may contain `/`-separated segments)
#   - cwd:  the repo the worktree should be registered against
# The hook derives the branch name, worktree directory, and base ref itself,
# creates the worktree, and prints its path to stdout. Exit 0 on success.
set -euo pipefail

input=$(cat)
name=$(jq -r '.name // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")

[[ -n "$name" ]] || { echo "worktree-create: missing 'name'" >&2; exit 1; }
[[ -n "$cwd"  ]] || { echo "worktree-create: missing 'cwd'"  >&2; exit 1; }

# Run git from the repo so the worktree is registered against it.
cd "$cwd"

# Worktree lives under .claude/worktrees/<name>, matching Claude Code's convention.
worktree_dir="$cwd/.claude/worktrees/$name"

# Apply the `jp/` branch convention. Leave already-prefixed names alone.
case "$name" in
  jp/*|jp.*) branch="$name" ;;
  worktree-*) branch="jp/${name#worktree-}" ;;
  *) branch="jp/${name}" ;;
esac

# Branch from origin's default branch for a clean tree, falling back to the
# remote's recorded HEAD and finally to local HEAD if the remote is unavailable.
base_ref=""
default_branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
if [[ -n "$default_branch" ]] && git rev-parse --verify --quiet "$default_branch" >/dev/null; then
  base_ref="$default_branch"
fi

# Send git's chatter to stderr so only the worktree path lands on stdout.
if git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null; then
  # Branch already exists — check it out directly without -b.
  git worktree add "$worktree_dir" "$branch" >&2
elif [[ -n "$base_ref" ]]; then
  git worktree add -b "$branch" "$worktree_dir" "$base_ref" >&2
else
  git worktree add -b "$branch" "$worktree_dir" >&2
fi

echo "$worktree_dir"
