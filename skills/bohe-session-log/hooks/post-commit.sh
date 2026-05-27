#!/bin/bash
# bohe-session-log: post-commit hook
# Works with Claude Code, Cursor, Codex, and any git workflow.
#
# What this does:
#   1. Appends a checkpoint stub to the branch draft file after every commit
#   2. Emits a magic keyword so Claude Code auto-triggers enrich mode
#      (other tools ignore this line — it's harmless stdout)

BRANCH=$(git branch --show-current 2>/dev/null | tr '/' '-')
[ -z "$BRANCH" ] && exit 0

ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$ROOT" ] && exit 0

DRAFT_DIR="$ROOT/docs/session-log"
DRAFT="$DRAFT_DIR/$BRANCH.draft.md"

mkdir -p "$DRAFT_DIR"

SHA=$(git rev-parse --short HEAD 2>/dev/null)
MSG=$(git log -1 --format="%s" 2>/dev/null)
TIME=$(date +%H:%M)

cat >> "$DRAFT" << EOF
## [$TIME] $MSG <!-- sha:$SHA -->
- $MSG
---
EOF

# Claude Code: triggers enrich mode to replace stub with conversation context.
# Cursor / Codex / other tools: this line is ignored.
echo "[MAGIC KEYWORD: bohe-session-log enrich]"
