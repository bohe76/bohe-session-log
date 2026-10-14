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

**Common definitions**
- **Store** = the main worktree's `docs/session-log/` (the path on the first line of `git worktree list --porcelain`). Resolve it in the same order as the hook: ① the main path has it → that; ② otherwise the current root has it → that; ③ neither → no store (this skill never creates one). Read it from any worktree — all worktrees share one store
- **Log files** = the files directly in the store that match `^.+-[0-9]{5}-[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$` (**excluding** the `drafts/` subfolder, legacy `*.draft.md` and any other md). **"Latest log"** = the newest of them by **mtime**
- **Branch name** = `git branch --show-current` with `/` replaced by `-` (`detached` on a detached HEAD). Which branch a log belongs to is decided by an **exact match** `^{branch}-[0-9]{5}-[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$` (escape regex metacharacters in the branch name; never a prefix glob — `main` would also match `main-v2-*`)
- **My draft** = `drafts/{branch}.draft.md`
- **Handoff draft** = a non-empty draft of another branch that meets both. ① Nobody writes to it — its branch is in no `branch refs/heads/…` line of `git worktree list --porcelain` (compared after the same `/`→`-` replacement), and, for a `detached` entry in the middle of a rebase or bisect, it is not the branch named by that worktree's `rebase-merge/head-name`·`rebase-apply/head-name`·`BISECT_START` (`git -C <worktree> rev-parse --path-format=absolute --git-path …`; compare without the `refs/heads/` prefix). Entries with a `prunable` line (directory gone) are ignored. Git never commits to a branch without checking it out and never checks one branch out in two worktrees, so a branch checked out nowhere has no writer. `detached` additionally requires no `detached` line in that list ② Nothing outside the 3-line stubs (`## [` line, the single `- ` line right after it, `---`) and blank lines (no hand-written notes). Merge status is an annotation, not a condition — "merged" if every `<!-- sha:` value gives `git merge-base --is-ancestor <sha> HEAD` exit 0, otherwise "not merged"

### 0. Unfinished-session detection

Compare my draft and the handoff drafts with **the global latest log** (any branch). If any of them is non-empty and newer than the global latest log (with no log at all, its mere existence counts), the previous session counts as unfinished — whichever branch it committed to, it ended without a session end.

Drafts of branches in progress in another worktree are not considered here (they appear in 1.5 as leftover drafts).

**When detected**, offer one line to the user:
> "There are commits not recorded since the last session log (the session ended without a session end, or commits came after it). Write the session log now?"

- Approved → the previous session may have ended in a crash (the draft stubs are commit messages only), so **first** obtain **the previous session's transcript** following the "Crash" row, the finding procedure and the token rules in `references/transcript_recovery.md` of the `bohe-session-log` folder installed next to this skill → run `bohe-session-log` with that as raw material **without Step 1 (committing work files)** (uncommitted changes are not committed) → continue afterwards
- Declined → skim the detected drafts' commit stubs (the list of commit messages), absorb them, continue

**Not detected** → skip silently.

### 1. Load context (L1–L2, absorbed inside the agent)

Read two layers into the agent's own working memory. Do not list each layer's contents to the user.

#### L1 — previous session (only the part after `<done>`)

**The global latest log by mtime** (any branch, draft excluded) → L1. Logs pile up in one store whichever branch the session ended on, and what you continue is the last session:
- If its frontmatter `branch` differs from the current branch, note "continuing work from another branch ({branch})" in the user output
- No log → "no previous session log"

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

Other work on other branches is picked up separately by 1.5 below. If L2 conflicts with the current code/files, **trust the current state** — the record is a past snapshot.

#### 1.5 — Inflow (what happened on other branches / worktrees)

Learn, from frontmatter only, what happened on other branches since you last left this one — whatever L1 did not already cover.

- **Candidates** = log files that are neither the current branch's nor L1, whose mtime is **newer than the current branch's latest log** (all of them if the current branch has no log)
- Newest first by mtime, **at most 5**. Read only `tldr` and `decisions_summary` from each frontmatter (no body)
- **Merge flag**: the file-name prefix has `/` replaced by `-`, so apply the same replacement to each branch from `git for-each-ref --format='%(refname:lstrip=2)' refs/heads` and find the match. If found, `git merge-base --is-ancestor <that branch> HEAD` — exit 0 "merged", 1 "not merged", anything else: omit the flag (a squash-merged branch shows as "not merged"). If not found → "branch deleted"
- **Leftover drafts**: non-empty files in `drafts/` other than the current branch → `{branch} (N stubs) [folded at session end (merged|not merged)|in progress|has notes — review]`. A handoff draft is **folded at session end** (the next session end, on any branch, absorbs and deletes it); one caught by ① (checked out in another worktree) is **in progress**; one caught by ② is **has notes — review** (the user reviews and cleans it up by hand; the commit messages remain in git)
- May overlap with L2 (accepted). Absorb `decisions_summary` internally; the user output gets only the two template lines below

### 2. User output (one compressed paragraph + TODOs)

After absorbing L1–L2, report to the user **briefly**. No long summaries.

```
## Context restored

Continuing from session {N} ({date}, {stage}{, continuing work from another branch {branch}}) — {tldr}.
Prior decisions: {core of the L2 decisions_summary — omit this line if none}.
{N} commits since the log{summarize 1–2 in parentheses only if important}.
Inflow from other branches: {branch}-{number} — {tldr} [merged|not merged|branch deleted] {up to 5 lines}
Leftover drafts: {branch} ({N} stubs) [folded at session end (merged|not merged)|in progress|has notes — review]{, …}

### Today's TODOs
- [ ] {TODO 1}
- [ ] {TODO 2}

Tell me which task to proceed with, or give me a different one.
```

- The body is only the template lines above — a one-glance view of the state to continue
- "Commits since the log" = commits on **the current branch** after the L1 log file's mtime (count with `git log --since=<L1 mtime> --oneline`). Even when L1 is another branch's log, count the current branch — what happened on this branch after that session. Omit the line when it is 0
- Details of `<done>`, `<decisions>`, `<blockers>` are not included in the user output (agent-internal only)
- Omit the unfinished-session line if nothing was detected. Omit the inflow / leftover-draft lines too when there is nothing to list. TODOs come from L1's `<todos>`; if none, replace with "tell me what to work on"
- If there is no session log at all: "No previous session log — new project", then wait for instructions

### 3. Ready (wait)

Wait for the user's instruction. **Never start work first** — even with `<todos>` present, act only after the user explicitly says so.

## Search mode (on explicit request)

For **log search requests** such as "find sessions about X", "search the session logs for Y", "when did we decide Z", answer with **a frontmatter grep instead of a full load**. A search request does not trigger the L1–L2 load. After presenting results, switch to context-load mode only when the user says "continue from this session".

1. **Map the query to fields**: domain/feature keyword → `tags:`; component/module/file name → `entities:`; decision wording → `decisions_summary:`; free text → `tldr:`; unclear → all four fields
2. **Grep frontmatter only** — in the store's log files, combine the field's leading line with the query. If a YAML list spans several lines, use a multiline pattern (`^tags:([^\n]*{query}|[^\n]*\n([ ]*- [^\n]*\n)*[ ]*- [^\n]*{query})`) to reach inside the list — the query matches only on the field's own line or its `- ` items (`[^\n]` instead of `.`, so it cannot cross lines or hit the next field). Escape regex metacharacters in the query, match case-insensitively, and accept a hit only inside the frontmatter (first `---` to second `---`)
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
- **Git worktrees share the store**: every worktree's logs and drafts land in the main worktree's `docs/session-log/`. Run from any worktree, this skill reads that store, and other worktrees' progress shows up through 1.5 (inflow / leftover drafts)
