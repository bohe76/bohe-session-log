#!/bin/bash
# bohe-session-log: git post-commit hook
# Works with Claude Code, Codex, Cursor, Antigravity, Grok, and any git workflow.
#
# Appends a commit-message stub to
#   <main worktree>/docs/session-log/drafts/<branch>.draft.md
# after every commit. One draft file per branch. Every linked worktree of a repo
# writes into the MAIN worktree's docs/session-log/, so drafts and logs survive
# `git worktree remove` and the main checkout sees every branch.
# The draft is raw material; the formal session log is written later by the
# bohe-session-log skill at session end (no LLM needed at commit time).
#
# Install (once) — see references/hook_setup.md in the skill folder:
#   mkdir -p ~/.git-hooks
#   cp <skill folder>/hooks/post-commit.sh ~/.git-hooks/post-commit
#   chmod +x ~/.git-hooks/post-commit
#   git config --global core.hooksPath ~/.git-hooks

# Git may export GIT_DIR into hook processes (it does in linked worktrees):
# never cd; run every git command from the hook's cwd and use the resolved
# paths only for file writes.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$ROOT" ] && exit 0

# Shared store = main worktree (always the first entry of `git worktree list`).
# Fallback to the current root when the main entry is bare or not activated
# (a v1 worktree-local store). Neither -> no-op.
MAIN=$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
STORE=""
[ -n "$MAIN" ] && [ -d "$MAIN/docs/session-log" ] && STORE="$MAIN/docs/session-log"
[ -z "$STORE" ] && [ -d "$ROOT/docs/session-log" ] && STORE="$ROOT/docs/session-log"

# Opt-in guard: repos without docs/session-log are a no-op (no global pollution)
[ -z "$STORE" ] && exit 0

# Rebase guard: commits re-applied by a rebase were already stubbed under their
# old SHA; without this they pile up in detached.draft.md with new SHAs.
for d in rebase-merge rebase-apply; do
  [ -d "$(git rev-parse --git-path "$d" 2>/dev/null)" ] && exit 0
done

BRANCH=$(git branch --show-current 2>/dev/null | tr '/' '-')
[ -z "$BRANCH" ] && BRANCH=detached

DRAFT_DIR="$STORE/drafts"
DRAFT="$DRAFT_DIR/$BRANCH.draft.md"

SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null) || exit 0
[ -z "$SHORT_SHA" ] && exit 0

# Duplicate guard: skip if this SHA is already in the branch draft (commit retries)
if [ -f "$DRAFT" ] && grep -qF "sha:${SHORT_SHA}" "$DRAFT" 2>/dev/null; then
  exit 0
fi

MSG=$(git log -1 --format='%s' 2>/dev/null)
[ -z "$MSG" ] && exit 0

# Meta-commit filter: commits that only touch docs/session-log/* are skipped
CHANGED=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null)
if [ -n "$CHANGED" ] && ! echo "$CHANGED" | grep -qv '^docs/session-log/'; then
  exit 0
fi

NOW=$(date '+%H:%M')
mkdir -p "$DRAFT_DIR" 2>/dev/null || exit 0

cat >> "$DRAFT" << EOF
## [$NOW] $MSG <!-- sha:$SHORT_SHA branch:$BRANCH -->
- $MSG
---
EOF
