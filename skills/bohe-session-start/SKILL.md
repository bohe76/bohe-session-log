---
name: bohe-session-start
description: >-
  Loads project context at session start so Claude can resume work seamlessly.
  Absorbs the previous session log and prior session decisions.
  Triggers on: "session start", "resume work", "continue", "where were we",
  "load context", "session log search", "find related session",
  "세션시작", "세션 시작", "업무준비", "업무 준비".
---

# bohe-session-start: Session Start Context Load + Session Log Search

A skill for **Claude to internalize project state** when a new conversation session begins. The goal is not to produce a long report for the user — it's for Claude itself to be ready to continue the previous session and be aware of prior decisions.

**Two operating modes**:
- **Context load mode** (default, triggers on "session start", "resume work", etc.): absorbs the latest session log + previous session decisions
- **Search mode** (triggers on "search session logs", "find sessions about XX", etc.): greps only frontmatter metadata to present relevant session candidates → reads full content only for the one the user selects

**Design philosophy**:
- In context load mode, L1 **reads only the latter half excluding `<done>`** — absorbs only `<decisions>`/`<pivots>`/`<open>`/`<blockers>`/`<todos>`/`<files>`. `<done>` (60–70% of the file) is unnecessary for resuming the next session, and is lazy-loaded only on user request
- L2 reads only the `decisions_summary` field from the 2nd most recent session (1 item). Without this, decisions from sessions before the most recent one would be missed at minimal cost
- In search mode, only grep frontmatter fields (`tags`, `entities`, `decisions_summary`, `related_sessions`, etc.) → quickly narrow down candidates without reading full files
- Output to user is **one short paragraph + TODOs only** — detailed summaries are kept internal to Claude only


## Context Load Mode (default)

### 0. Unfinished session detection

Check current branch name, then compare mtimes of the draft and the latest session log:

```bash
BRANCH=$(git branch --show-current | tr '/' '-')
DRAFT="docs/session-log/${BRANCH}.draft.md"
LATEST_LOG=$(ls -t docs/session-log/${BRANCH}-*.md 2>/dev/null | head -1)
```

**Decision condition** — treat as unfinished if BOTH conditions are met:
1. Draft file exists and is non-empty (`-s`)
2. No session log exists, or draft is newer than the log (`draft -nt LATEST_LOG`)

**If unfinished detected**, suggest in one line to the user:
> "It looks like the previous session wasn't closed. Would you like to write the session log now?"

- Approved → run `bohe-session-log` → continue after completion
- Declined → briefly read and absorb draft as supplementary L1 context, then continue

**Not detected** (no draft or draft is older than log) → skip silently.

---

### 1. Load context materials (L1–L2, absorbed internally by Claude)

Read both layers and absorb them into Claude's own working memory. Do not enumerate each layer's contents to the user.

#### L1 — Most recent session (latter half only, excluding `<done>`)

**Most recent file by mtime** (excluding draft):

```bash
ls -t docs/session-log/*.md | grep -v '\.draft\.md' | head -1
```

- If no file exists → "no previous session log"
- If the adopted log's frontmatter `branch` differs from the current git branch, indicate "continuing from a different branch ({branch name})" in the user output

**Read strategy — load only from `</done>` onwards**:
- Run `grep -n '</done>' <file>` to find the closing line number
- Specify `offset=<that line>` in the Read tool → skip the `<done>` section (saves 60–70% of file)
- If no `</done>` found (legacy MD format) → fall back to reading the full file

**Items to absorb** (essential for resuming next session):
- `<decisions>` — confirmed items that must not be reversed
- `<pivots>` — direction change reasons (to avoid repeating mistakes)
- `<open>` — unresolved questions
- `<blockers>` — waiting on external items
- `<todos>` — tasks to continue (included in user output)
- `<files>` — files recently touched

**`<done>` is lazy-read**: only re-read the same file (without `offset`, or with `limit=<done end>`) when the user explicitly asks "what did we do last session in detail".

**Legacy log compatibility**: Old format logs without XML tags (only MD headers like `## What was done`) should be read in full and parsed by MD sections. Both new and old formats coexist and both can be read.

#### L2 — 2nd most recent session's decisions (decisions_summary only)

Extract only the `decisions_summary` field from the frontmatter of the 2nd most recent file by mtime (1 item):

```bash
SECOND=$(ls -t docs/session-log/*.md | grep -v '\.draft\.md' | sed -n '2p')
[ -n "$SECOND" ] && awk '/^---$/{n++; if(n==2){exit}} n==1 && /^decisions_summary:/' "$SECOND"
```

**Purpose**: L1 reads the most recent session's decisions via `<decisions>`, but this provides minimal-cost reinforcement so decisions from even earlier sessions aren't missed. Skip silently if no 2nd file exists.

---

### 2. User output (compressed one paragraph + TODOs)

After absorbing L1–L2, report **briefly** to the user. No long summaries.

```
## Context Restored

Continuing from session {N} ({date}, {stage}) — {one-line tldr}.
Prior decisions: {L2 decisions_summary accumulated core — omit this line if none}.
{N} additional commit(s) after log {summarize 1–2 important ones in parentheses if any}.

### Today's TODOs
- [ ] {TODO 1}
- [ ] {TODO 2}

Please tell me what to work on, or give me a different task.
```

**Compression principles**:
- Body within 3 lines
- `<done>`/`<decisions>`/`<blockers>` details are not included in user output (internal to Claude only)
- Omit the unfinished detection line if it wasn't triggered
- TODOs come from L1's `<todos>`. If none, replace with "Please tell me what to work on"

If there are no previous session logs at all, indicate "No previous session log — this appears to be a new project or new branch" and wait for task instructions.

---

### 3. Ready to work (standby)

Wait for user instructions. **Never start work proactively** — even if `<todos>` exist in the session log, act only after the user explicitly gives instructions.

---

## Search Mode (on explicit request)

When the user makes a **log search request** like "find sessions about XX", "search session logs for YY", "when did we decide ZZ", respond with **frontmatter grep instead of full load**.

### Search procedure

1. **Map search term → field**:
   - Domain/feature keywords → `tags:` field
   - Component/module/file names → `entities:` field
   - Decision text → `decisions_summary:` field
   - Free text → `tldr:` field (one-line summary)
   - Unclear → search all 4 fields above

2. **Run grep** (targeting frontmatter block only):
   - Use Grep tool on `docs/session-log/*.md`
   - Frontmatter is only between `---`~`---` at the top, so combine `tags:`/`entities:`/`decisions_summary:`/`tldr:` start lines + search term
   - Use multiline if needed: `^tags:.*\n(  - .*\n)*.*{term}` to reach inside YAML lists

3. **Present candidate list**:
   - One line per matched session: `{filename} — {tldr} ({date}, {stage})`
   - Maximum 10. If more, show "top 10 of N total"

4. **Wait for user selection**:
   - When instructed "read sessions 1 and 3 in full", read only those files
   - Can end without selection

### Legacy log search fallback

Old-format session logs don't have `tags`/`entities`/`decisions_summary`/`related_sessions` fields in frontmatter. Grepping only `tags:` would miss all old-format logs.

**Fallback procedure** (automatically applied when new-field grep returns 0 results):

1. **1st pass**: grep `tags:`/`entities:`/`decisions_summary:` fields (new-format logs)
2. **0 results → 2nd pass**: grep `tldr:` field for the search term (common to both formats)
3. **2nd pass also 0 results → 3rd pass (only after user confirmation)**: suggest full body grep
   - Ask: "No matches in new fields or tldr. Expand to full body grep?"
   - Run only if approved — do not auto-run without user confirmation (high cost)

**Mark in results**:
- Old-format logs in candidate list: `{filename} — {tldr} ({date}, legacy)` with `legacy` marker
- If user says "exclude legacy", filter to new-format only

### Search mode principles

- **No full file Read in search phase**: only frontmatter. Read full body only when user points to a specific session.
- **No guessing**: if no frontmatter match, honestly report "no session tagged with that keyword". Expansion to body grep requires user confirmation.
- **Separate from context load mode**: search requests do not trigger L1–L2 full load. After presenting search results, switch to context load mode only when user explicitly says "continue this session".

---

## Notes

- This skill is **read-only** — it does not modify or create session logs (that's `bohe-session-log` skill's role)
- **L1 in context load mode reads only the latter half excluding `<done>`** — absorbs only `<decisions>`/`<pivots>`/`<open>`/`<blockers>`/`<todos>`/`<files>`. Do not summarize from frontmatter alone or read everything including `<done>`. `<done>` details are lazy-loaded via re-Read on user request.
- **Search mode's frontmatter grep must not be confused with full Read** — search is for narrowing down "which session is relevant"; actual context requires a full Read of the selected session.
- **Claude internalization is the goal** — user report is one compressed format. Do not proactively provide detailed summaries. Expand only when user asks "tell me more".
- In context load mode, L1/L2 are by mtime regardless of branch — identify which branch each file is from by the branch name in the filename
- If L2 conflicts with older information, **trust the current code/files** — records seen in skills are past snapshots
- **Legacy log compatibility**: old-format logs without XML tags (only MD headers) must also be parseable. Understand the mappings: `## What was done` ↔ `<done>`, `## Decisions` ↔ `<decisions>`, etc.
