#!/bin/bash
# bohe-session-log installer (macOS / Linux / Windows-via-Git-Bash)
# Supports: Claude Code, Codex, Cursor, Antigravity CLI, Grok, and any git-based workflow.
#
# Design:
#   - Hook script is copied to a STABLE location (~/.bohe-session-log/)
#     so deleting this cloned repo doesn't break the hook.
#   - Existing core.hooksPath is RESPECTED — we install into the user's
#     existing hooks directory rather than overwriting their config.
#   - Existing post-commit hook is APPENDED to, not overwritten.
#   - Skills are installed only for tools detected on this machine.
#   - An existing skill folder (or symlink) is replaced, never nested into.
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

SKILL_NAMES="bohe-session-log bohe-session-start"
SKILLS_INSTALLED=0

# install_skills <skills-dir> <label>
install_skills() {
  local target="$1" label="$2" name
  mkdir -p "$target"
  for name in $SKILL_NAMES; do
    # rm -rf on a symlink removes the link itself, not what it points to.
    rm -rf "${target:?}/$name"
    cp -r "$SKILLS_SRC/$name" "$target/$name"
  done
  printf '✓ %-12s → %s\n' "$label" "$target"
  SKILLS_INSTALLED=$((SKILLS_INSTALLED + 1))
}

echo "bohe-session-log installer"
echo "=========================="

# ── 1. Copy hook to stable location ─────────────────────────────────────────
mkdir -p "$STABLE_DIR"
cp "$HOOK_SRC_REPO" "$STABLE_HOOK"
chmod +x "$STABLE_HOOK"
echo "✓ Hook script  → $STABLE_HOOK"

# ── 2. Skills: one copy per detected tool ───────────────────────────────────
[ -d "$HOME/.claude" ]                 && install_skills "$HOME/.claude/skills"                 "Claude Code"
[ -d "$HOME/.codex" ]                  && install_skills "$HOME/.codex/skills"                  "Codex"
[ -d "$HOME/.cursor" ]                 && install_skills "$HOME/.cursor/skills"                 "Cursor"
[ -d "$HOME/.gemini/antigravity-cli" ] && install_skills "$HOME/.gemini/antigravity-cli/skills" "Antigravity"
[ -d "$HOME/.grok" ]                   && install_skills "$HOME/.grok/skills"                   "Grok"

# ── 3. Git hook — respect existing config, append don't overwrite ───────────
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
if [ "$SKILLS_INSTALLED" -eq 0 ]; then
  echo "⚠ No supported AI tool detected (~/.claude / ~/.codex / ~/.cursor / ~/.gemini/antigravity-cli / ~/.grok)."
  echo "  Skills were not installed. Git hook works regardless of AI tool."
else
  echo "Done. Restart your AI tool to activate the skills."
fi

echo ""
echo "Note: a repo-local core.hooksPath (husky, .githooks, ...) shadows the global hook."
echo "      See skills/bohe-session-log/references/hook_setup.md for the 2-line chain call."
echo ""
echo "Quick test (in a repo that has docs/session-log/ — create it to opt in):"
echo "  mkdir -p docs/session-log && git commit --allow-empty -m 'test hook'"
echo "  cat docs/session-log/drafts/<branch>.draft.md   # should have one stub entry"
echo ""
echo "Triggers:"
echo "  bohe-session-log   — 'end session', 'save session', '세션 종료'"
echo "  bohe-session-start — 'session start', 'where were we', '세션 시작'"
