#!/bin/bash
# bohe-session-log installer (macOS / Linux / Windows-via-Git-Bash)
# Supports: Claude Code, Codex (OMX), Cursor, and any git-based workflow.
#
# Design:
#   - Hook script is copied to a STABLE location (~/.bohe-session-log/)
#     so deleting this cloned repo doesn't break the hook.
#   - Existing core.hooksPath is RESPECTED — we install into the user's
#     existing hooks directory rather than overwriting their config.
#   - Existing post-commit hook is APPENDED to, not overwritten.
#
# Usage:
#   bash install.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
HOOK_SRC_REPO="$SKILLS_SRC/bohe-session-log/hooks/post-commit.sh"

# Stable hook location — survives repo deletion
STABLE_DIR="$HOME/.bohe-session-log"
STABLE_HOOK="$STABLE_DIR/post-commit.sh"

SKILLS_INSTALLED=0

echo "bohe-session-log installer"
echo "=========================="

# ── 1. Copy hook to stable location ─────────────────────────────────────────
mkdir -p "$STABLE_DIR"
cp "$HOOK_SRC_REPO" "$STABLE_HOOK"
chmod +x "$STABLE_HOOK"
echo "✓ Hook script  → $STABLE_HOOK"

# ── 2. Skills: Claude Code ──────────────────────────────────────────────────
if [ -d "$HOME/.claude" ]; then
  TARGET="$HOME/.claude/skills"
  mkdir -p "$TARGET"
  cp -r "$SKILLS_SRC/bohe-session-log" "$TARGET/"
  cp -r "$SKILLS_SRC/bohe-session-start" "$TARGET/"
  echo "✓ Claude Code  → $TARGET"
  SKILLS_INSTALLED=$((SKILLS_INSTALLED + 1))
fi

# ── 3. Skills: Codex (OMX) ──────────────────────────────────────────────────
if [ -d "$HOME/.codex" ]; then
  TARGET="$HOME/.codex/skills"
  mkdir -p "$TARGET"
  cp -r "$SKILLS_SRC/bohe-session-log" "$TARGET/"
  cp -r "$SKILLS_SRC/bohe-session-start" "$TARGET/"
  echo "✓ Codex        → $TARGET"
  SKILLS_INSTALLED=$((SKILLS_INSTALLED + 1))
fi

# ── 4. Cursor (no native skills dir; git hook handles capture) ──────────────
if [ -d "$HOME/.cursor" ]; then
  echo "✓ Cursor       → git hook covers commit capture (no skill auto-trigger)"
fi

# ── 5. Git hook — respect existing config, append don't overwrite ───────────
EXISTING_HOOKS_PATH="$(git config --global --get core.hooksPath 2>/dev/null || true)"
if [ -n "$EXISTING_HOOKS_PATH" ]; then
  HOOK_DIR="$EXISTING_HOOKS_PATH"
  echo "  Detected existing core.hooksPath → $HOOK_DIR (preserving)"
else
  HOOK_DIR="$HOME/.git-hooks"
fi

# Expand ~ if present in user's config
HOOK_DIR="${HOOK_DIR/#\~/$HOME}"
mkdir -p "$HOOK_DIR"

EXISTING_HOOK="$HOOK_DIR/post-commit"
MARKER="# bohe-session-log: post-commit draft capture"

if [ -f "$EXISTING_HOOK" ]; then
  if grep -q "bohe-session-log" "$EXISTING_HOOK" 2>/dev/null; then
    echo "✓ Git hook     → already installed in $EXISTING_HOOK (skipped)"
  else
    # Append to existing hook — never overwrite user's content
    {
      echo ""
      echo "$MARKER"
      echo "bash \"$STABLE_HOOK\""
    } >> "$EXISTING_HOOK"
    chmod +x "$EXISTING_HOOK"
    echo "✓ Git hook     → appended to existing $EXISTING_HOOK"
  fi
else
  # Fresh install — create new hook that delegates to stable script
  cat > "$EXISTING_HOOK" << EOF
#!/bin/bash
$MARKER
bash "$STABLE_HOOK"
EOF
  chmod +x "$EXISTING_HOOK"
  echo "✓ Git hook     → $EXISTING_HOOK"
fi

# Only set core.hooksPath if it wasn't already configured
if [ -z "$EXISTING_HOOKS_PATH" ]; then
  git config --global core.hooksPath "$HOOK_DIR"
  echo "✓ Git config   → core.hooksPath=$HOOK_DIR"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
if [ "$SKILLS_INSTALLED" -eq 0 ] && [ ! -d "$HOME/.cursor" ]; then
  echo "⚠ No supported AI tool detected (~/.claude / ~/.codex / ~/.cursor)."
  echo "  Skills were not installed. Git hook works regardless of AI tool."
else
  echo "Done. Restart your AI tool to activate the skills."
fi

echo ""
echo "Quick test:"
echo "  cd <any git repo> && git commit --allow-empty -m 'test hook'"
echo "  cat docs/session-log/<branch>.draft.md   # should have one stub entry"
echo ""
echo "Triggers:"
echo "  bohe-session-log   — 'end session', 'save session', '세션 종료'"
echo "  bohe-session-start — 'session start', 'where were we', '세션 시작'"
