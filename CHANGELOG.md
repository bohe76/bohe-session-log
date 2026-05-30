# Changelog

Change history for session management skills (bohe-session-log, bohe-session-start) and the installer.

---

## [Unreleased]

### bohe-session-log
- **Removed enrich mode — switched to git-hook stub-only** — dropped the post-commit LLM enrichment of draft stubs. The git post-commit hook now appends commit-message stubs only (no LLM); content is consolidated into the formal log at session end. Side effect: the `[MAGIC KEYWORD]` echo and the Claude-only keyword-detector dependency are gone, so **draft capture now works uniformly across all tools (Claude/Codex/Cursor/...)**. Draft quality as "raw material" is sufficient; final log quality is guaranteed by the session-end LLM. Cleaned enrich residue from the description, the "Using the Draft" example, Step 1, and update-mode rules; removed the Enrich Mode section.

### post-commit hook (`hooks/post-commit.sh`)
- **Rewritten as stub-only union** — brought the shared reference in line with v1.6.0 (single `session.draft.md`, `<!-- sha:short branch:BRANCH -->` header) that the file had drifted from, and added safety guards: opt-in guard (no-op unless `docs/session-log/` exists — prevents the global `core.hooksPath` from polluting every repo), duplicate-SHA skip, and meta-commit filter. Removed the `[MAGIC KEYWORD]` emit.

### bohe-session-start
- **Step 0 bugfix** — added `2>/dev/null` to `ls`, made the empty-`LATEST_LOG` case explicit (`[ -z "$LATEST_LOG" ]` branch). Prevents missed detection in environments without session logs, e.g. new worktrees
- **L1 branch-first selection** — prefer the current branch's latest log over the globally newest file by mtime, falling back to mtime when absent. Fixes loss of current-branch prior-session context after a branch switch
- **Notes addition** — documented Git worktree isolated session space behavior
- **Review fix** — corrected the "L1/L2 by mtime regardless of branch" note that contradicted the new L1 branch-first logic (clarified the L1 branch-first / L2 global-2nd asymmetry); added `grep -v draft` to the `BRANCH_LOG` glob for consistency with `GLOBAL_LOG`

---

## [1.6.0] — 2026-05-27

### bohe-session-log
- **Unified draft file** — replaced per-branch `{branch}.draft.md` with a single `session.draft.md` across all branches
- Stub header now includes `branch:$BRANCH` metadata so the correct branch context is preserved in the shared file
- `session.draft.md` is parsed by reading the `branch:` field in each `## [HH:MM]` block header
- Enrich mode updated: no longer resolves branch-specific path; reads the last block from `session.draft.md` directly

### bohe-session-start
- Step 0 unfinished-session detection updated to use `session.draft.md` and branch-agnostic log glob

### post-commit hook (`hooks/post-commit.sh`)
- Draft path changed from `docs/session-log/${BRANCH}.draft.md` → `docs/session-log/session.draft.md`
- Stub header format changed to `<!-- sha:SHA branch:BRANCH -->` for branch identification
- Duplicate check updated to match on `sha:SHA` substring (format-agnostic)

---

## [1.5.0] — 2026-05-27

### Installer
- **Expanded tool support** — Cursor, Gemini CLI, and Antigravity CLI now detected and installed alongside Claude Code and Codex
- Cursor skills now copied to `~/.cursor/skills/` (previously only git hook capture was noted)
- Added Gemini CLI detection → `~/.gemini/skills/`
- Added Antigravity CLI detection → `~/.antigravity/skills/` (Google's official Gemini CLI successor)
- Warning message on no-tool-detected updated to list all five supported tools

### README
- Tool support matrix expanded to include Cursor, Gemini CLI, Antigravity CLI — all five tools share the same skill auto-trigger mechanism
- Added skill install locations table
- Removed `(OMX)` label from Codex row

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
