---
name: bohe-session-start
description: >-
  Context-loading skill for session start: the running agent absorbs the previous session log's decisions, open items and TODOs so it is ready to continue. Also provides a frontmatter-based session-log search mode. Use on requests like "session start", "where were we", "continue", "what did we do last time", "load context", "latest session log", "search session logs", "find related sessions", "세션 시작", "업무 준비", "이어서", "세션 로그 검색".
---

# bohe-session-start: Context load at session start + session-log search

A skill for **the running agent to internalize the project state** when a new conversation session begins. The goal is not a long report to the user — it is the agent itself continuing from the previous session and being aware of earlier decisions. **Read-only**: it never creates or modifies session logs (that is `bohe-session-log`'s job).

**Two modes**
- **Context-load mode** (default — "session start", "where were we", …): absorb the previous session log + earlier decisions
- **Search mode** ("search session logs", "find sessions about X", …): grep frontmatter metadata only, present a candidate list → read in full only what the user picks

**Design principle — "lightweight resume"**
- L1 reads **only the part after `<done>`** — absorb `<decisions>`/`<pivots>`/`<open>`/`<blockers>`/`<todos>`/`<files>` only. `<done>`, even summarized, is the largest part of the body and is not needed to continue. Lazy-read it on user request. When "what exactly was done last time" is needed, use search mode / a lazy read of `<done>`
- L2 is only the `decisions_summary` field of the second-newest session (one). L1 alone can miss decisions from the session before it; this is the minimum-cost backstop. `entities`, `related_sessions` and the body are not read
- Output to the user is **one short paragraph + TODOs** only — detailed summaries stay inside the agent
- Context restoration only. A session-start request alone never starts a remote pull, merge, deploy, or execution of previous TODOs

## Context-load mode (default)

Common definitions — **"latest log"** = the newest file by **mtime** among `docs/session-log/*.md`, **excluding** `*.draft.md`. **Branch name** = `git branch --show-current` with `/` replaced by `-`.

### 0. Unfinished-session detection

Compare the mtime of `docs/session-log/session.draft.md` with the latest log. The previous session counts as unfinished when **both** hold:
1. The draft file exists and is **not empty**
2. There is **no session log at all**, **or** the draft is newer than the latest log

**When detected**, offer one line to the user:
> "The previous session doesn't seem to have been closed. Write the session log now?"

- Approved → the previous session may have ended in a crash (the draft stubs are commit messages only), so **first** obtain **the previous session's transcript** following the "Crash" row, the finding procedure and the token rules in `references/transcript_recovery.md` of the `bohe-session-log` folder installed next to this skill → run `bohe-session-log` with that as raw material → continue afterwards
- Declined → skim the draft's commit stubs (the list of commit messages), absorb them, continue

**Not detected** (no draft, empty draft, or draft older than the log) → skip silently.

### 1. Load context (L1–L2, absorbed inside the agent)

Read two layers into the agent's own working memory. Do not list each layer's contents to the user.

#### L1 — previous session (only the part after `<done>`)

**Current branch's newest first, falling back to the global newest by mtime** (draft excluded in all cases):
- Newest by mtime among the current branch's logs (`{branch}-*.md`) → L1
- None → the global latest log → L1. Its frontmatter `branch` may differ from the current branch → note "continuing work from another branch ({branch})" in the user output
- None at all → "no previous session log"

**Read range — load from `</done>` onward**: find the line number of `</done>` in the file and read only what follows (skips the `<done>` section, most of the body). If there is no `</done>` (legacy Markdown format), fall back to reading the whole file.

**Items to absorb** (required to continue):
- `<decisions>` — settled items, not to be reversed
- `<pivots>` — reasons for direction changes (avoid repeating mistakes)
- `<open>` — unresolved questions
- `<blockers>` — external waits
- `<todos>` — work to continue (included in the user output)
- `<files>` — changes outside git (global config, memory, releases, … touched recently)

**`<done>` is lazy-read**: only when the user asks "what exactly did we do last session", re-read the same file to extract it.

**Legacy log compatibility**: old-format logs without XML tags (`## 한 일` / Markdown headers) are read in full and parsed by Markdown section (`## 한 일` ↔ `<done>`, `## 결정사항` ↔ `<decisions>`, …). Mixed old/new logs are both handled.

#### L2 — decisions of the second-newest session (`decisions_summary` only)

From the frontmatter (between the first `---` and the second `---` at the top) of the **global second-newest** log by mtime (any branch, draft excluded), extract only the `decisions_summary` field. If the YAML list spans several lines, include only its indented items. If there is no second file, skip silently.

L1 is branch-first while L2 is global-second — an asymmetry: if another branch holds a newer log, that session's decisions may be caught by neither L1 nor L2 (accepted; L2's purpose is "backstop decisions from the session before the previous one", so it stays branch-agnostic). If L2 conflicts with the current code/files, **trust the current state** — the record is a past snapshot.

### 2. User output (one compressed paragraph + TODOs)

After absorbing L1–L2, report to the user **briefly**. No long summaries.

```
## Context restored

Continuing from session {N} ({date}, {stage}) — {tldr}.
Prior decisions: {core of the L2 decisions_summary — omit this line if none}.
{N} commits since the log{summarize 1–2 in parentheses only if important}.

### Today's TODOs
- [ ] {TODO 1}
- [ ] {TODO 2}

Tell me which task to proceed with, or give me a different one.
```

- The body is only the template lines above — a one-glance view of the state to continue
- "Commits since the log" = commits on the current branch after the L1 log file's mtime (count with `git log --since=<L1 mtime> --oneline`). Omit the line when it is 0
- Details of `<done>`, `<decisions>`, `<blockers>` are not included in the user output (agent-internal only)
- Omit the unfinished-session line if nothing was detected. TODOs come from L1's `<todos>`; if none, replace with "tell me what to work on"
- If there is no session log at all: "No previous session log — new project or new branch", then wait for instructions

### 3. Ready (wait)

Wait for the user's instruction. **Never start work first** — even with `<todos>` present, act only after the user explicitly says so.

## Search mode (on explicit request)

For **log search requests** such as "find sessions about X", "search the session logs for Y", "when did we decide Z", answer with **a frontmatter grep instead of a full load**. A search request does not trigger the L1–L2 load. After presenting results, switch to context-load mode only when the user says "continue from this session".

1. **Map the query to fields**: domain/feature keyword → `tags:`; component/module/file name → `entities:`; decision wording → `decisions_summary:`; free text → `tldr:`; unclear → all four fields
2. **Grep frontmatter only** — in `docs/session-log/*.md`, combine the field's leading line with the query. If a YAML list spans several lines, use a multiline pattern (`^tags:.*\n(  - .*\n)*.*{query}`) to reach inside the list
3. **Legacy fallback** — old-format logs lack `tags`/`entities`/`decisions_summary`/`related_sessions` and are missed by the first grep. In order:
   - 1st: grep `tags:`·`entities:`·`decisions_summary:` (new format)
   - 0 hits → 2nd: grep `tldr:` (common to old and new formats)
   - still 0 → 3rd, **only after the user confirms**: full-body grep ("No match in the new fields or tldr. Extend to a full-body grep?"). It is expensive; never run it automatically
4. **Present candidates** — one line per matching session: `{file name} — {tldr} ({date}, {stage})`. Mark old-format logs as `({date}, legacy)` (filter them out on "exclude legacy"). At most 10; if more, say "newest 10 of N"
5. **Wait for the user's pick** — read in full only the files the user names ("read 1 and 3 in full"). Ending without a pick is fine

**Principles**: during search, read frontmatter only (no full-file reads). If nothing matches in the frontmatter, do not guess — report honestly "no session tagged with that keyword". Search narrows down *which* sessions are relevant; the actual context comes from reading the chosen session in full.

## Notes

- This skill is **read-only** — it never modifies or creates session logs
- In context-load mode, L1 is a read of the part after `<done>`. Do not summarize from the frontmatter alone, and do not read everything including `<done>`
- Do not volunteer detailed summaries. Expand only when the user asks for "more detail"
- **Git worktrees are independent session spaces**: each worktree's `docs/session-log/` is physically isolated. Search only the logs in the current worktree. If another worktree's logs are needed, read them by specifying that worktree's path explicitly
