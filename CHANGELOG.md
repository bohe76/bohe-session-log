# Changelog

Change history for session management skills (bohe-session-log, bohe-session-start) and the installer.

---

## [1.4.0] — 2026-05-27

### Installer
- **Cross-platform support** — added `install.ps1` / `uninstall.ps1` for Windows-native PowerShell users (bash installer still works on macOS / Linux / Git Bash)
- **Stable hook location** — hook script now copied to `~/.bohe-session-log/post-commit.sh`; deleting the cloned repo no longer breaks the hook
- **Respects existing `core.hooksPath`** — installer detects pre-existing config and installs into that same directory instead of overwriting
- **Append-only hook integration** — if `post-commit` already exists, append a delegation line instead of overwriting user's content
- Added `uninstall.sh` / `uninstall.ps1` — strips delegation lines, removes stable hook, deletes skills; preserves `core.hooksPath` and project session logs

### Skills
- **Korean trigger keywords** added to skill descriptions: `"세션 종료"`, `"세션 시작"`, `"업무 준비"`, etc.

### Repo
- Added `LICENSE` (MIT)
- Added `.github/` issue and PR templates
- README: cross-platform install commands, requirements, verification step, troubleshooting, tool support matrix, uninstall instructions

---

## [1.3.0] — 2026-05-27

### bohe-session-start
- **Removed model-specific execution strategy section** — model routing logic removed; exploration uses the main model directly
- **Simplified L1 selection logic** — 4-rule (current branch priority + global latest fallback) → latest 1 file by mtime. Removed `docs/handoffs/` fallback
- **Simplified L2** — recent 3 files × decisions_summary → only the 2nd most recent session's decisions_summary

### bohe-session-log
- **Trimmed legacy format coexistence rules** — removed the dedicated section detailing how to handle old and new formats side by side. Brief compatibility note retained so old logs still parse
- **Cleaned up notes section** — consolidated general notes (no code details, plan references, no artifact duplication, XML notes) into the notes section

---

## [1.2.0] — 2026-05-27

### bohe-session-start
- Strengthened L1 file selection logic — 4-rule "current branch priority + global latest fallback":
  - Compare current branch candidate (max number) vs global latest candidate (by mtime)
  - If adopted log's branch differs from current branch, show "continuing from different branch"
  - Auto-continues recent work even after branch switching in gitignored environments
- Added `docs/handoffs/` fallback — if directory exists, compare with latest file by mtime
- Added 3-tier legacy log search fallback:
  1. New fields (`tags`/`entities`/`decisions_summary`) grep
  2. Auto-expand to `tldr:` field grep on 0 results (common to old and new formats)
  3. Full body grep on 0 results — only after user confirmation

### bohe-session-log
- Added **no artifact duplication** principle — no copying of PRDs/plans/ADRs/issues/commits/diffs into `<done>`; path/URL references only
- Added `decisions_summary` **domain prefix convention** — optional `[domain] decision body` format for projects that want to link decisions to feature areas
- Added **`.draft.md` integration detail rules** for update mode:
  - Regular bullets → `<done>` tag `### Update HH:MM` section
  - `[decision]` bullets → appended to end of `<decisions>` tag
  - `stage`/`tldr` overwrite; `tags`/`entities`/`decisions_summary` merge existing + new
  - Multiple time entries in draft → consolidate under latest time

### Project Structure
- Added `skills/` directory — forks skill sources into the project repo for git-tracked management

---

## [1.1.0] — 2026-04-30

### bohe-session-start
- Minimal L2 change: "recent 5 files × 7 frontmatter fields" → "only `decisions_summary` field from the 2nd most recent file". Reduced context waste + improved handover accuracy
- Removed L4 (project status) section entirely — overlaps with CLAUDE.md role, violates lazy loading principle
- Removed L3 (unmerged commits) section — LOG_COMMIT calculation not possible since docs/session-log/ is gitignored
- Step 0: draft briefing → replaced with unfinished session detection — compare draft mtime vs latest session log mtime
- Reduced layer structure from L1–L4 to L1–L2

### bohe-session-log
- Replaced `## Initial Setup` section with sentinel file-based auto-check — skip immediately if `.setup_done` exists; confirm hook then create if not
- Removed yes/no choice at session end → always proceeds to log unconditionally
- Added enrich mode — auto-triggers after git commit, replaces last draft stub with conversation context
- Added `hooks/` directory (shared reference files)
  - `hooks/post-commit.sh` — standalone git hook version
  - `hooks/settings-snippet.json` — Claude Code PostToolUse hook registration guide

### bohe-session-checkpoint
- Declared deprecated — fully replaced by bohe-session-log enrich mode

---

## [1.0.0] — 2026-04-20

### bohe-session-log, bohe-session-start
- Overhauled session log format to XML tag-based structure
  - `<done>`, `<decisions>`, `<pivots>`, `<open>`, `<blockers>`, `<todos>`, `<files>`
  - `<done>` lazy read — load only the latter half (`</done>` onwards) at session start
- Added frontmatter search-dedicated fields: `tags`, `entities`, `decisions_summary`, `related_sessions`
- Added bohe-session-start search mode — present candidate sessions via frontmatter grep
