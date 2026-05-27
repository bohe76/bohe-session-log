#!/bin/bash
# bohe-session-log installer
# Supports: Claude Code, Codex (OMX), and any git-based workflow.
#
# Usage:
#   bash install.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
HOOK_SRC="$SKILLS_SRC/bohe-session-log/hooks/post-commit.sh"
INSTALLED=0

echo "bohe-session-log installer"
echo "=========================="

# ── 1. Skills: Claude Code ──────────────────────────────────────────────────
if [ -d "$HOME/.claude" ]; then
  TARGET="$HOME/.claude/skills"
  mkdir -p "$TARGET"
  cp -r "$SKILLS_SRC/bohe-session-log" "$TARGET/"
  cp -r "$SKILLS_SRC/bohe-session-start" "$TARGET/"
  echo "✓ Claude Code  → $TARGET"
  INSTALLED=$((INSTALLED + 1))
fi

# ── 2. Skills: Codex / OMX ──────────────────────────────────────────────────
if [ -d "$HOME/.codex" ]; then
  TARGET="$HOME/.codex/skills"
  mkdir -p "$TARGET"
  cp -r "$SKILLS_SRC/bohe-session-log" "$TARGET/"
  cp -r "$SKILLS_SRC/bohe-session-start" "$TARGET/"
  echo "✓ Codex        → $TARGET"
  INSTALLED=$((INSTALLED + 1))
fi

# ── 3. Skills: Cursor ───────────────────────────────────────────────────────
# Cursor uses Rules, not skills. No skill install needed.
# The git hook below still captures commits from Cursor sessions.
if [ -d "$HOME/.cursor" ]; then
  echo "  Cursor detected — git hook covers commit tracking (no skill dir needed)"
fi

# ── 4. Global git hook ──────────────────────────────────────────────────────
HOOK_DIR="$HOME/.git-hooks"
mkdir -p "$HOOK_DIR"

EXISTING_HOOK="$HOOK_DIR/post-commit"
if [ -f "$EXISTING_HOOK" ] && ! grep -q "bohe-session-log" "$EXISTING_HOOK" 2>/dev/null; then
  # Merge with existing hook — append our script call
  echo "" >> "$EXISTING_HOOK"
  echo "# bohe-session-log" >> "$EXISTING_HOOK"
  echo "bash \"$HOOK_SRC\"" >> "$EXISTING_HOOK"
  echo "✓ Git hook     → merged into existing $EXISTING_HOOK"
else
  cp "$HOOK_SRC" "$EXISTING_HOOK"
  chmod +x "$EXISTING_HOOK"
  echo "✓ Git hook     → $EXISTING_HOOK"
fi

git config --global core.hooksPath "$HOOK_DIR"
echo "✓ Git config   → core.hooksPath=$HOOK_DIR"

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
if [ "$INSTALLED" -eq 0 ] && [ ! -d "$HOME/.cursor" ]; then
  echo "⚠ No supported AI tool detected (~/.claude / ~/.codex / ~/.cursor)."
  echo "  Skills were not installed. Copy skills/ manually to your tool's skills directory."
  echo "  Git hook was installed regardless — it works with any workflow."
else
  echo "Done. Restart your AI tool to activate the skills."
fi
echo ""
echo "  bohe-session-log  — say 'end session' or 'save session'"
echo "  bohe-session-start — say 'session start' or 'where were we'"
