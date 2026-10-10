# Changelog

Change history for session management skills (bohe-session-log, bohe-session-start) and the installer.

---

## [2.0.0] — 2026-10-10

### One store per repository — branches and worktrees (hook + both skills)
- **The store is the main worktree's `docs/session-log/`** — the hook, bohe-session-log and bohe-session-start all resolve it from the first line of `git worktree list --porcelain`. Commits and logs from linked worktrees collect in the main checkout, so they survive `git worktree remove` (measured: a worktree holding only ignored logs is removed without `--force`, taking the logs with it) and a session on main sees every branch. Resolution order is identical in the hook and both skills: main has the store → main; otherwise the current root has it → current root (a v1 worktree-local store, migration target); neither → none (Step 0 creates it on main). A bare main is flagged as unsupported rather than handled
- **One draft per branch** — `session.draft.md` → `drafts/{branch}.draft.md`. No shared write between concurrent worktrees; the session-end reset is a file delete; unfinished detection is "my branch's draft exists and is non-empty". A remaining file marks a branch that ended without a log. Reverts the v1.6.0 single-file decision (its reason, the enrich mode, is gone; parallel worktrees are the real usage pattern). The stub header keeps `branch:`
- **Hook** — resolves the main worktree, writes under `drafts/`, never `cd`s (git exports `GIT_DIR` into hooks run from linked worktrees). New **rebase guard**: commits re-applied by a rebase are skipped (they were already stubbed under their old SHA and used to pile up in `detached.draft.md`). 17-check test matrix in a temp repo with linked worktrees passes (store location from main and worktree, `feature/x` → `feature-x`, detached HEAD, duplicate SHA, meta-commit filter, opt-in guard, survival after worktree remove, fallback, LF) plus 5 rebase checks (merge and apply backends, worktree rebase, a real detached commit is still recorded)
- **bohe-session-log** — store rule (①②③ above); Step 0 creates the dir on the main side, runs `check-ignore` against the store's repo root and uses `git rev-parse --path-format=absolute --git-path info/exclude` (a linked worktree's `.git` is a file, so the literal path does not exist, and without `--path-format` the path is cwd-relative); branch membership by exact match `^{branch}-[0-9]{5}-[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$` instead of a prefix glob (`main` used to match `main-v2-*`; `\d` silently matches nothing in `grep -E`, hence `[0-9]`, anchors, and escaping of branch-name metacharacters); `detached` as the branch name on a detached HEAD; per-branch draft read/delete; pointer to the legacy-draft migration; logs must stay untracked (a tracked log's mtime jumps on every checkout — untrack with `git rm --cached` only with the user's approval, in a separate commit, after a backup). The interim "announce other branches' stubs before the reset" rule below is dropped — per-branch files make it moot
- **bohe-session-start** — common definitions (store, log-file pattern, exact match, my draft); branch-scoped unfinished detection (no more false positives from other branches' commits); new layer **1.5 Inflow**: other-branch logs newer than the current branch's latest log, at most 5, frontmatter only, with a merged / not merged / branch-deleted flag (file-name prefix matched against `git for-each-ref` branches after the same `/`→`-` replacement; `git merge-base --is-ancestor` exit 0 / 1 / other = merged / not merged / no flag), plus other branches' leftover drafts split into "in progress" (branch checked out in some worktree per `git worktree list`) and "no log"; on a fresh branch the log adopted as L1 is excluded from the candidates; a leftover draft is folded by ending the session on that branch, never from the current one (the earlier "write it here" sentence was removed — it would have produced a log under the current branch's name); search mode reads the store, not the cwd; two optional output lines; worktree note now describes the shared store
- **references/hook_setup.md** — main-worktree rule and resolution order, bare-main warning, `git worktree repair`, `GIT_DIR` caution, rebase guard, verify path, one-time "Migrating legacy drafts" procedure (split the single draft by `branch:` and put old stubs in front of any existing file to keep chronology; stubs without `branch:` and anything before the first stub → `drafts/legacy.draft.md`; move root-level `*.draft.md` only when it has `<!-- sha:` headers, merging same-name files instead of overwriting; leave hand-written notes; move a v1 worktree-local store into main, renumbering same-name logs)
- **Second independent review** — REQUEST_CHANGES (2 MAJOR, 11 MINOR, 9 NIT, no CRITICAL) folded into the items above. Two calls made: the "write another branch's log from here" sentence was removed instead of growing a procedure, and a bare main is documented as unsupported instead of handled. Delta re-review **APPROVE** (3 new MINOR, 3 NIT); five applied: run the migration when the store resolves to a worktree-local one, compare worktree branches with the same `/`→`-` replacement, drafts of deleted branches / `legacy` are reviewed and deleted by hand, the rebase guard is described as skipping every commit during a rebase, migration step 3 creates the main store first, moves untracked files only and fixes `session`/title on renumber. One ignored: two local branches collapsing to the same replaced name (`feature/x` vs `feature-x`)
- **Upgrade impact (breaking)** — the draft path changed; an existing `session.draft.md` needs the one-time migration. Together with dropping Gemini CLI, this is the reason for v2.0.0
- Tokens (tiktoken o200k_base, Korean source, final after the delta re-review): session-log **7,470 → 5,304 (−29%)**, session-start **4,560 → 3,838 (−16%)**. The figures in the two skill sections below (4,602 / 2,850) are the intermediate values before this change. References: `hook_setup.md` 1,917 (incl. the migration procedure), `transcript_recovery.md` 1,092

### bohe-session-log
- **Tool-neutral single procedure** — removed the "runtime branches" (Claude/Unix vs Codex/Windows sections, PowerShell/Bash example blocks, model-specific delegation directives, `.setup_done` marker). Only git commands remain as shell; file operations are described in words. The same `SKILL.md` is installed for every supported tool
- **Dead Codex route dropped** — references to a repo-local `{branch}.draft.md` writer were removed. It had not fired since the 2026-05-27 switch to the global `core.hooksPath` hook and contradicted the stub-only design
- **Progressive disclosure via `references/`** — rarely needed procedures moved out of the main body and are read only when triggered: `references/transcript_recovery.md` (crash / compaction recovery) and `references/hook_setup.md` (hook install/verify). `hook_setup.md` adds guidance for repos whose **local `core.hooksPath` (husky, `.githooks`) shadows the global hook**: a two-line chain call instead of copying the hook body (which drifts)
- **Structure** — "new log vs update" decision folded into Step 2 of the session-end workflow; the read-only "how the next session reads this" aside was removed; the update-mode rules are now their own section; notes de-duplicated. Template, the 7 tags, frontmatter schema, compression rules and the domain-prefix rule are unchanged
- **Frontmatter fix** — the description no longer contains escaped literal quotes (they showed up verbatim in skill listings). Both skills now pass a strict YAML parser (Antigravity CLI refuses to load skills with frontmatter errors)
- **Semantics tightened after an independent review** — the draft is reset by the main agent only after verification passes (and no longer by a delegated helper); a hint is shown at Step 1 when commits were made but the draft stayed empty (hook not running / shadowed); update-mode sub-headings only on tags that receive content; transcript recovery: the crash case excludes the current session's own record, summaries are for scope only, no full-persistence claim; hook setup: 4-condition install gate, warning that a global `core.hooksPath` disables every repo's `.git/hooks/*`, chain snippet with `chmod +x` / insert-before-`exit` / `bash` call
- Branch handling in the single draft made explicit: only the current branch's stubs (by the stub header `branch:` field) go into the log; stubs from other branches are announced (branch + count) before the draft is reset, since they vanish with it — interim rule until the branch/worktree logic pass
- Tokens (tiktoken o200k_base, Korean source): **7,470 → 4,602 (−38%)**; references ≈ 1.1K each, loaded on demand

### bohe-session-start
- **Tool-neutral single procedure** — removed the runtime/tool branch section and the PowerShell/Bash blocks. The boundary conditions those blocks encoded are now stated explicitly in prose: "latest log" = newest by mtime excluding `*.draft.md`; unfinished = draft non-empty **and** (no log at all **or** draft newer than the latest log); L1 = current branch's newest log, falling back to the global newest with a "continuing from branch X" note; read from `</done>` onward with full-file fallback for legacy logs; L2 = `decisions_summary` of the global second-newest log only
- **Scope cleanup** — project-specific routing sentences removed; kept only the general rule that a session-start request never triggers pull/merge/deploy or executing previous TODOs
- **Description fix** — replaced the stale "unmerged commits + project status" claim (removed in v1.1.0) with the actual L1/L2 + search-mode behavior
- Unfinished-session approval flow ordered explicitly (obtain the previous transcript first, then run `bohe-session-log` with it); "commits since the log" in the output template defined as commits after the L1 log's mtime (`git log --since`), omitted when 0
- Tokens (Korean source): **4,560 → 2,850 (−37%)**

### Installer / README
- **Supported tools: Claude Code · Codex · Cursor · Antigravity CLI · Grok.** Gemini CLI dropped. Antigravity CLI path corrected to `~/.gemini/antigravity-cli/skills/` (official docs; the previous `~/.antigravity/skills/` does not exist). Grok installs to `~/.grok/skills/`
- Skills are copied only for tools detected on the machine, and an existing skill folder (or symlink/junction) is **replaced in place** — fixes nested `bohe-session-log/bohe-session-log/` copies produced by `cp -r` into an existing directory on re-install
- Uninstallers now clean every supported tool directory (previously only Claude Code and Codex)
- Quick-test instructions fixed: the hook is opt-in per repo (`docs/session-log/` must exist) and the draft file is `docs/session-log/drafts/<branch>.draft.md`
- README: tool matrix, install locations, `references/` table, a troubleshooting entry for repo-local `core.hooksPath`, a "Branches and worktrees" section describing the shared store, and the git requirement raised to 2.31+ (`--show-current`, `--path-format`)

---

## [1.10.0] — 2026-06-04

### bohe-session-log
- **Body compression guide — prose → keyword-compressed form** — codifies writing the body tags (`<done>`/`<decisions>`/`<open>`/`<todos>`, etc.) as keyword-compressed form rather than prose. Measured: same log, prose → compressed ≈ **−17%** tokens (beats full English translation's −13.4%, with zero search/readability cost; tiktoken o200k_base). Key design: `<done>`'s "key narrative summary" is the *information-selection* axis, compression is the *expression* axis — separate, so compression **only trims expression and never drops facts/decisions/rationale**. Six rules (drop particles/connectives, preserve all information, keep identifiers/paths/hashes/versions + error messages/quotes/command strings verbatim, express causation with `→`, keep the language, frontmatter unchanged) + one before/after example. Frontmatter schema and 7-tag set unchanged; no effect on bohe-session-start (read-only)

---

## [1.9.1] — 2026-06-01

### bohe-session-log
- **tags/entities guidance — "this session's distinctive traits" principle** — session logs are a closed set searched only within `docs/session-log/`, so tags/entities carry only what distinguishes this session from other session logs. Words common to every session (skill names like `session-log`/`session-start`) are excluded as non-discriminative. Frontmatter table wording also corrected ("Core keyword search" → "Identify this session (in-folder search)").

---

## [1.9.0] — 2026-05-31

### bohe-session-log
- **`<files>` tag redefined — only changes git doesn't track** — committed repo files are delegated to `git log` (no duplication); `<files>` now records only global (`~/.claude`·`~/.git-hooks`), memory, releases/tags, and other-repo changes
- **`<done>` is now a key narrative summary** — not an exhaustive list, just the trunk the next session needs (details backed by transcript & git)
- **`<decisions>` = session ADR, layer clarified** — the session log retains the full decision story; only "always-apply" rules are promoted to memory (layers, not duplicates)
- Tag set of 7 kept as-is (done/decisions/pivots/open/blockers/todos/files)

### bohe-session-start
- **"Lightweight resume" made explicit** — L1 absorbs only minimal continue-context; deeper context via search mode / `<done>` lazy Read. `<files>` absorb item updated to "changes outside git". Softened the "60–70% of file" figure to a qualitative phrase (no real contradiction with `<done>` summarization)

---

## [1.8.0] — 2026-05-31

### bohe-session-log
- **Transcript-based recovery** — guards against sessions that didn't end gracefully (crash/compaction). The draft is stub-only (commit messages), so recovery was thin; now the **conversation transcript** (which persists in full on disk regardless of compaction) is read as raw material. Two cases: ① **compaction** (session-end Step 2 — current session transcript) ② **crash** (`bohe-session-start` unfinished detection — previous session transcript). Discovery is delegated to each agent ("find your CLI's record by cwd + latest") with per-tool hints (Claude `~/.claude/projects/`, Codex `~/.codex/sessions/`, Antigravity CLI `~/.gemini/antigravity-cli/`). Token management: scope (since last log) · filter (drop tool noise + skill-load + `<system-reminder>` → ~1/40) · **sub-agent delegation** protects main context → zero cost on a graceful end. hook/stub/draft format unchanged. **Verified end-to-end on Claude**: discovery → filter (3.4MB→84KB) → sub-agent (Haiku) recovery at 92% confidence

### bohe-session-start
- **Crash-recovery fallback** — on Step 0 unfinished detection (approved), recover from the previous session's transcript (see `bohe-session-log` §Transcript Recovery "Crash")

---

## [1.7.0] — 2026-05-31

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
