---
name: bohe-session-log
description: >-
  Writes or updates a session log so work can continue seamlessly in the next session.
  Triggers on keywords: "session log", "save session", "end session", "session off",
  "wrap up session", "session done". Also auto-triggers in enrich mode when a git
  commit hook emits "[MAGIC KEYWORD: bohe-session-log enrich]".
---

# bohe-session-log: Session Log Management

Records each session's work (discussions + implementation) so the next session can resume without any gap.

**Format design principle**: This log is primarily for the next session's Claude to parse accurately. AI parsing accuracy takes priority over human readability — that's why the body uses XML tags for explicit section boundaries, and the frontmatter carries metadata for log search.

## Storage Location

`docs/session-log/` directory at the project root.

The directory is auto-created if missing. Session logs and drafts are **gitignored** — they are personal work records and should not be git-tracked.

## File Naming

**Formal log**: `{branch}-{number}-{YYYY-MM-DD}.md`

- Branch: current git branch name (`/` replaced with `-`. e.g. `feature/chat` → `feature-chat`)
- Number: 5-digit zero-padded (`00001`, `00002`, ...) — **max existing number for that branch + 1**
- Date: `YYYY-MM-DD` format
- Examples: `main-00020-2026-04-14.md`, `feature-chat-00001-2026-04-14.md`

**Draft**: `{branch}.draft.md`
- Example: `main.draft.md`, `feature-chat.draft.md`
- One per branch; accumulates checkpoint stubs appended by the post-commit hook

## Behavior

### 1. Create a new session log (default)

Check `docs/session-log/` and decide based on these rules:

1. Extract the current branch name (`git branch --show-current`, `/` → `-`)
2. Find the latest log file for that branch (`{branch}-*.md`)
3. Latest file is **today's date** and **same context** → update the existing file (append as history)
4. Latest file is **today's date** but **different context** → increment number and create a new file
5. Latest file is **a past date** → increment number and create a new file (with today's date)

**Context judgment criteria:**
- If existing log's `<done>` and the current session work are continuous → update
- If currently executing the existing log's `<todos>` → update
- If covering a completely different screen/feature/topic → new file

### 2. Read the previous session log

At the start of the next session, read the **latest log for the current branch** and:
- Check `<todos>`
- Check `<open>`, `<blockers>`
- Resume work

(See `bohe-session-start` skill for detailed load order)

### 3. Write content

Analyze the current conversation context and `{branch}.draft.md`, then automatically fill in each section of the template below.
**Save directly without proposing a draft first** (do not ask the user).

#### Using the Draft

Always check the current branch's `{branch}.draft.md` before ending a session:

- File **exists**: read as raw material for writing the log, then reset after saving (overwrite with empty file)
- File **does not exist**: write the log from conversation context alone (normal case)

`.draft.md` is a cumulative file of stubs appended by the post-commit hook on every git commit. Format:

```
## [10:23] feat(studio): AI chat panel to floating
- Fixed right sidebar → fixed bottom-right floating panel
- [decision] Width w-[448px] confirmed, sidebar approach abandoned
---
## [11:45] fix(ChatPanel): block selection context retention bug
- .border-l selector → #chat-panel-wrapper id
---
```

**Parse by splitting on `## [HH:MM]`**. Regular bullets go into the `<done>` tag; `[decision]` bullets go into `<decisions>`.

If the session crashed multiple times or formal logs have been missing for an extended period, the draft may accumulate content across multiple days. In that case, **treat the entire draft as raw material** and consolidate it into a single formal log — do not treat it as stale.

## Template

```markdown
---
session: {number}
branch: {branch}
date: {YYYY-MM-DD}
project: {project name}
stage: {planning / design / implementation / verification / done}
tldr: {one-line summary}
tags: [{domain/feature keywords}]
entities: [{key component/module/file names}]
decisions_summary: [{key decisions, one-line each}]
related_sessions: [{previous related session filenames or numbers}]
---

# Session {number} — {YYYY-MM-DD} ({branch})

<done>
- (chronological, discussions and implementation mixed)
</done>

<decisions>
- Confirmed items (must not be reversed)
</decisions>

<pivots>
- ~~previous direction~~ → new direction (reason)
</pivots>

<open>
- Open questions, deferred discussions
</open>

<blockers>
- Things awaiting external action or confirmation
</blockers>

<todos>
- [ ] Tasks to start immediately next session
</todos>

<files>
- `path/to/file` — what was done
</files>
```

## Section Writing Guide

| Tag | Meaning | Content | Can be empty |
|-----|---------|---------|:---:|
| `<done>` | What was done | Everything done this session (discussions, research, implementation, debugging, etc.) | ❌ Required |
| `<decisions>` | Decisions | Confirmed items. Must not be reversed next session | ⭕ Omit tag if empty |
| `<pivots>` | Direction changes | What changed direction this session and why | ⭕ Omit tag if empty |
| `<open>` | Unresolved | Questions without answers yet, deferred discussions | ⭕ Omit tag if empty |
| `<blockers>` | Waiting | User actions, external confirmations, etc. blocking progress | ⭕ Omit tag if empty |
| `<todos>` | Next session TODOs | Work to start immediately next session. Checkbox format | ❌ Required |
| `<files>` | Changed files | Files created/modified/deleted this session | ⭕ Omit tag if empty |

## Frontmatter Field Guide

| Field | Content | Search use | Example |
|-------|---------|-----------|---------|
| `session` | Number | Identification | `5` |
| `branch` | Branch name | Identification | `feature-chat` |
| `date` | Date | Chronological filter | `2026-04-20` |
| `project` | Project name | Project filter | `my-project` |
| `stage` | Phase | Phase filter | `implementation` |
| `tldr` | One-line summary | Preview | — |
| `tags` | Domain/feature keyword list | **Core keyword search** | `[chat, ui, auth]` |
| `entities` | Key component/module/file name list | **Entity tracking** | `[ChatPanel, useAuth]` |
| `decisions_summary` | Key decisions, one-line summaries | **Decision search** | `["w-[448px] floating fixed", "pnpm adopted"]` |
| `related_sessions` | Previous related session filenames/numbers | **Session linking** | `[feature-chat-00003-2026-04-14]` |

`tags` / `entities` / `decisions_summary` / `related_sessions` are optional but **fill them out as much as possible to improve searchability**. Empty list `[]` is allowed.

**tags guide**: Use domain/feature area words common in the current project. Remove duplicates. 3–8 items recommended.

**entities guide**: Use actual code symbol names/file names as-is, so they can be found with grep during search.

**decisions_summary guide**: Compress each `<decisions>` body item to 10–20 words. Leave empty if body is empty.

**Domain prefix convention** (optional but recommended for projects with a wiki):
- Format each item as `[domain] decision body`
- domain = a feature area or module name from your project (e.g. auth/api/ui)
- Split multi-domain decisions into separate items
- Decisions not tied to a specific domain may use `[general]` or omit the prefix
- Examples:
  - `"[auth] JWT 24h + refresh 7d"`
  - `"[api] pagination cursor-based"`
  - `"[general] coverage gate added to CI"`

## Session End Workflow

When the user says "end session" or equivalent, follow this sequence:

### Step 1 — Commit work files

Check `git status` for changes:
- Changes exist → git add + git commit **work files only** (exclude session log and draft)
  - The post-commit hook automatically appends a stub to the draft and emits the enrich signal
  - Enrich mode auto-triggers to replace the last draft stub with conversation context
- No changes → skip commit, proceed to step 2

### Step 2 — Write session log

Write the session log by analyzing the current conversation context and the draft file.

**Recommended**: delegate to a sub-agent when the session is long or complex (dozens of commits, multiple domains). For short sessions, write directly.

**Procedure**:

1. Read `{branch}.draft.md` — enriched entries are the raw material
2. Fill in the template: classify entries into done/decisions/pivots/open/blockers/todos/files; extract tags/entities/decisions_summary
3. Write to `docs/session-log/{branch}-{number}-{YYYY-MM-DD}.md`
4. Reset draft (overwrite with empty file)
5. Verify result — frontmatter required fields + XML tag pairs + filename consistency

### Step 3 — End

Simply end after log is complete. No need to suggest `/clear`.

---

## Enrich Mode

**Trigger**: post-commit hook emits `[MAGIC KEYWORD: bohe-session-log enrich]` after a commit → skill auto-fires.

**Behavior**:

1. Check current branch, determine draft path
2. Read the **last `##` block** in the draft (= the stub for the commit just made)
3. Replace the "what was done" bullets (commit message repeat) with **specific content based on conversation context**
   - Add `[decision]` bullets if relevant
   - Do not modify the header (`## [HH:MM] ...`) or `---` separator
4. Report in one line after completion:
   ```
   ✓ enrich: [HH:MM] {commit message}
   ```

**Before (stub):**
```
## [10:23] feat(chat): floating panel switch <!-- sha:abc123 -->
- feat(chat): floating panel switch
---
```

**After (enriched):**
```
## [10:23] feat(chat): floating panel switch <!-- sha:abc123 -->
- Fixed right sidebar → fixed bottom-right floating panel structure
- [decision] Width w-[448px] confirmed, sidebar approach abandoned
---
```

**Notes**:
- Only modify the last block — do not touch other entries
- Never repeat the commit message — replace with more specific content
- Maximum 5 lines per entry
- If draft file is missing or last block parsing fails → notify user of failure reason

---

## Notes

- Empty sections are **omitted including the XML tag** (do not leave empty tags)
- Frontmatter `stage` has 5 levels: planning / design / implementation / verification / done
- Frontmatter `project` uses the current working directory's project name
- Multiple sessions on the same branch on the same day → increment number only (date may be identical)
- Numbers are **independent per branch** — feature branches start fresh from 00001
- **When updating, do not freely add/delete existing content** — always append in history format
  - Add content inside existing XML tag blocks with a `### Update {HH:MM or "afternoon session"}` subheading (must not go outside the tag)
  - Keep existing `<decisions>`/`<pivots>` and only add new items
  - For `<todos>`, mark completed items with `~~strikethrough~~` then add new items
  - Deleting existing content is absolutely forbidden — even incorrect content must be preserved with `~~strikethrough~~`
  - **Draft integration in update mode**:
    - Draft entry regular bullets go into `<done>` tag body under `### Update HH:MM` section
    - `[decision]` bullets are appended at the end of `<decisions>` tag
    - Frontmatter `stage`/`tldr` are overwritten to reflect current state
    - Frontmatter `tags`/`entities`/`decisions_summary` are **merged** with existing (deduplicated)
    - If draft has multiple time entries, consolidate all under `### Update` with the latest time
- Do not write code details — only path and summary in `<files>`
- Reference detailed plans by path only (do not copy content)
- **No artifact duplication** — content already in PRDs, plans, ADRs, issues, commits, or diffs must not be copied into the body; use path/URL references only (e.g. `details: docs/prd/auth.md#token-policy`)
- **XML tag notes**:
  - Tag names are lowercase, no underscores, fixed to the 7 tags above
  - Always match opening/closing pairs — mismatches will break parsing in the next session
  - Markdown bullets/checkboxes/strikethrough are all allowed inside tags

## Setup Check (Automatic)

On first invoke, check whether the global git hook is installed:

```bash
git config --global core.hooksPath  # should point to a directory containing post-commit
```

- **Hook found** → proceed normally, no output
- **Hook not found** → notify the user once:

```
⚠ bohe-session-log: git hook not detected.
  Commit stubs won't be captured until the hook is installed.
  Run: bash install.sh  (from the bohe-session-log repo)
  Or visit: https://github.com/bohe76/bohe-session-log
```

Do not block normal skill operation — the skill works without the hook (draft-less mode: writes the session log from conversation context only).
