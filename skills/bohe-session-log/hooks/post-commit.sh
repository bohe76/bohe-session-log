#!/bin/bash
# bohe-session-log: git post-commit hook
# Works with Claude Code, Cursor, Codex, and any git workflow.
#
# Appends a checkpoint stub (commit message) to docs/session-log/session.draft.md
# after every commit. The draft is raw material; the full session log is written
# later by the bohe-session-log skill at session end (no LLM needed at commit time).
#
# Install (once):
#   mkdir -p ~/.git-hooks
#   cp ~/.claude/skills/bohe-session-log/hooks/post-commit.sh ~/.git-hooks/post-commit
#   chmod +x ~/.git-hooks/post-commit
#   git config --global core.hooksPath ~/.git-hooks

ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$ROOT" ] && exit 0

DRAFT_DIR="$ROOT/docs/session-log"
DRAFT="$DRAFT_DIR/session.draft.md"

# Opt-in 가드: docs/session-log 없는 프로젝트는 no-op (전역 hooksPath 오염 방지)
[ ! -d "$DRAFT_DIR" ] && exit 0

BRANCH=$(git branch --show-current 2>/dev/null | tr '/' '-')
[ -z "$BRANCH" ] && BRANCH=detached

SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null) || exit 0
[ -z "$SHORT_SHA" ] && exit 0

# 중복 방지: 이 SHA가 draft에 이미 있으면 skip (커밋 재시도 포함)
if [ -f "$DRAFT" ] && grep -qF "sha:${SHORT_SHA}" "$DRAFT" 2>/dev/null; then
  exit 0
fi

MSG=$(git log -1 --format='%s' 2>/dev/null)
[ -z "$MSG" ] && exit 0

# 메타 커밋 필터: docs/session-log/* 만 변경한 커밋은 skip
CHANGED=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null)
if [ -n "$CHANGED" ] && ! echo "$CHANGED" | grep -qv '^docs/session-log/'; then
  exit 0
fi

NOW=$(date '+%H:%M')

cat >> "$DRAFT" << EOF
## [$NOW] $MSG <!-- sha:$SHORT_SHA branch:$BRANCH -->
- $MSG
---
EOF
