#!/bin/bash
# bohe-session-log uninstaller (macOS / Linux / Windows-via-Git-Bash)
#
# Removes:
#   - Skills from ~/.claude/skills/ and ~/.codex/skills/
#   - Stable hook script in ~/.bohe-session-log/
#   - Hook delegation lines from $(core.hooksPath)/post-commit
#
# Preserves:
#   - User's other hooks and core.hooksPath setting
#   - Project session logs in docs/session-log/
#
# Usage:
#   bash uninstall.sh

set -e

STABLE_DIR="$HOME/.bohe-session-log"

echo "bohe-session-log uninstaller"
echo "============================"

# ── 1. Skills: Claude Code ──────────────────────────────────────────────────
for tool_dir in ".claude" ".codex"; do
  TARGET="$HOME/$tool_dir/skills"
  if [ -d "$TARGET/bohe-session-log" ] || [ -d "$TARGET/bohe-session-start" ]; then
    rm -rf "$TARGET/bohe-session-log" "$TARGET/bohe-session-start"
    echo "✓ Skills       → removed from $TARGET"
  fi
done

# ── 2. Hook delegation in post-commit ───────────────────────────────────────
HOOKS_PATH="$(git config --global --get core.hooksPath 2>/dev/null || true)"
HOOKS_PATH="${HOOKS_PATH/#\~/$HOME}"
[ -z "$HOOKS_PATH" ] && HOOKS_PATH="$HOME/.git-hooks"

POST_COMMIT="$HOOKS_PATH/post-commit"
if [ -f "$POST_COMMIT" ]; then
  if grep -q "bohe-session-log" "$POST_COMMIT" 2>/dev/null; then
    # Strip our lines (marker + bash line + leading blank)
    tmp="$(mktemp)"
    awk '
      /^# bohe-session-log: post-commit draft capture$/ { skip = 1; next }
      skip && /^bash .*\.bohe-session-log.*post-commit\.sh/ { skip = 0; next }
      { print }
    ' "$POST_COMMIT" > "$tmp"

    # If file is now empty or only shebang/blank lines, remove entirely
    if [ ! -s "$tmp" ] || ! grep -q '[^[:space:]#!/bin/bash]' "$tmp"; then
      # Check if only shebang remains
      remaining="$(grep -v '^#!' "$tmp" | grep -v '^[[:space:]]*$' || true)"
      if [ -z "$remaining" ]; then
        rm -f "$POST_COMMIT"
        echo "✓ Hook         → $POST_COMMIT (removed — was empty)"
      else
        mv "$tmp" "$POST_COMMIT"
        chmod +x "$POST_COMMIT"
        echo "✓ Hook         → bohe-session-log lines stripped from $POST_COMMIT"
      fi
    else
      mv "$tmp" "$POST_COMMIT"
      chmod +x "$POST_COMMIT"
      echo "✓ Hook         → bohe-session-log lines stripped from $POST_COMMIT"
    fi
    rm -f "$tmp"
  fi
fi

# ── 3. Stable hook script ───────────────────────────────────────────────────
if [ -d "$STABLE_DIR" ]; then
  rm -rf "$STABLE_DIR"
  echo "✓ Hook script  → removed $STABLE_DIR"
fi

echo ""
echo "Done."
echo ""
echo "NOT touched (intentionally):"
echo "  - core.hooksPath setting (your other hooks may rely on it)"
echo "  - docs/session-log/ in your projects (personal records)"
