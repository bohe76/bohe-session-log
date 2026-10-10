---
name: bohe-session-log
description: >-
  Writes the session log at session end so the next session can pick up where this one left off. Use on requests like "end session", "save session", "wrap up", "session off", "세션 종료", "세션 저장", "세션 마무리", "세션오프". Commit stubs are appended to the draft automatically by the git post-commit hook; this skill writes the formal session log when the user asks to end the session.
---

# bohe-session-log: Writing the session log

Records what the session did (discussion + implementation) so the next session continues without a gap.

**Format principle**: the top priority is that **the next session's AI agent parses this log exactly**. Parsing accuracy beats human readability. So the body marks section boundaries with XML tags, and the frontmatter carries search metadata.

**Trigger**: fires only when the user asks to "end / save / wrap up / record the session". **It does not fire on every commit.** Appending a stub to the draft right after a commit is done by the git post-commit hook with no LLM involved (draft = raw material, formal log = written at session end from the conversation context).

If this skill file has already been read in the current session and has not changed since, do not read it again; reuse the context. This skill neither widens nor narrows the scope the user approved or the project's required verification.

## Location and file names

`docs/session-log/` under the project root. If it does not exist, Step 0 of the session-end workflow creates it. Session logs and the draft are personal work records and are excluded from git tracking. Prefer **`.git/info/exclude`** (local only, leaves no trace in a public repo); if `.gitignore` already ignores them, leave it as is.

**Formal log**: `{branch}-{number}-{YYYY-MM-DD}.md`
- branch: current git branch name (`/` replaced by `-`; `feature/chat` → `feature-chat`)
- number: 5-digit zero-padded — **max existing number for that branch + 1**. Numbers are **independent per branch** (a feature branch starts at 00001). Several sessions on the same day and branch just increment the number
- e.g. `main-00020-2026-04-14.md`, `feature-chat-00001-2026-04-14.md`

**Draft**: `session.draft.md` — a single file regardless of branch, accumulating commit stubs (each stub header records `branch:`)

## Draft (raw material)

Always check `session.draft.md` before ending the session.
- Exists: read it as raw material, and after the log is saved, reset it to an empty file
- Missing or empty: write the log from the conversation context alone (normal case)

The draft is the accumulation of stubs that the installed git post-commit hook appends on every commit. Each stub carries **only the commit message** (no LLM — only what git knows). Format:

```
## [10:23] feat(studio): AI chat panel to floating <!-- sha:abc123 branch:main -->
- feat(studio): AI chat panel to floating
---
```

**Split on `## [HH:MM]`.** Fold the commit messages into `<done>` in chronological order; information the stubs lack (decisions, pivots, …) is **extracted from the conversation context** into the matching tags (`<decisions>`, `<pivots>`, …). If several days have piled up (crashes, a long stretch without a formal log), treat **the whole draft as raw material** and consolidate it into one formal log — do not treat it as stale.

## Session-end workflow

When the user says "end session" or equivalent, follow this order.

### Step 0 — Ensure the session-log directory (activation)

Do this before committing, so the hook recognizes this repo from the Step 1 commit onward.

1. Create `docs/session-log/` if missing
2. Check tracking exclusion: `git check-ignore -q docs/session-log/session.draft.md`
   - Already ignored → skip
   - Otherwise add one line `docs/session-log/` to **`.git/info/exclude`** (not `.gitignore`)
   - ⚠️ **Always check with the file path.** Checking the directory path (`docs/session-log/`) misreports "not ignored" as soon as any git-tracked file exists inside it (you would add an info/exclude entry that is not needed)

Where the global hook is installed, this step "activates" the repo: from now on **every tool's commits are caught by the hook**. Commits made before activation are missing only from the draft; the formal log is written from the conversation context, so nothing is lost.

### Step 1 — Commit the work files

After checking `git status`:
- Changes present → add and commit **work files only** (exclude session logs and the draft). The hook appends a stub to the draft
- No changes → skip the commit

**Continue even if no hook is installed.** The draft is simply empty; the log is written from the conversation context. If this session made commits but the draft is empty, mention in one line that the hook may not be running (not installed, or a repo-local `core.hooksPath` shadows the global hook), and follow `references/hook_setup.md` in this skill's folder only if the user wants it checked or installed. Never install just because the session is ending.

### Step 2 — Write the session log

1. **New file vs update** — look at the current branch's latest log (`{branch}-*.md`):
   - Latest file is **today** + **same context** → update the existing file (§Update mode)
   - Today but different context, or a past date → new file with number +1 (today's date)
   - Context test: update if the existing `<done>` continues into the current work or the existing `<todos>` are being executed; new file if the topic (screen/feature/subject) is entirely different
2. **Gather raw material** — `session.draft.md` + conversation context. The draft is a single file, so **tell branches apart by the `branch:` field in each stub header** and fold only the current branch's stubs into this log. **If the session was compacted (context compression) at any point**, the current context is a summary and details are missing → follow `references/transcript_recovery.md` in this skill's folder to read the current session's transcript (unnecessary on a normal end)
3. **Write** — fill in per §Template, §Section guide and §Frontmatter guide. **Save directly, without proposing a draft** (do not ask the user). Short or simple sessions are written by the main agent itself. Delegate to a helper worker only when delegation actually improves the write-up quality or the context cost; the delegation prompt must then include: branch, next number, today's date; the draft's absolute path; a core summary of the conversation (tag-classification hints + entities/tags/decisions_summary hints); the obligation to follow this skill's guides; the output absolute path
4. **Verify (main agent)** — required frontmatter fields, matching XML tag pairs, file name consistency
5. **Reset the draft (main agent, after verification passes)** — overwrite with an empty file. Never empty it before verifying (a failed write would lose the raw material)

### Step 3 — End

After the log is done, just end. No extra guidance needed.

## Template

```markdown
---
session: {number}
branch: {branch}
date: {YYYY-MM-DD}
project: {project name}
stage: {planning / design / implementation / verification / done}
tldr: {one-line summary}
tags: [{topic keywords unique to this session}]
entities: [{main components/modules/files}]
decisions_summary: [{one-line summaries of key decisions}]
related_sessions: [{file names or numbers of related earlier sessions}]
---

# Session {number} — {YYYY-MM-DD} ({branch})

<done>
- (chronological key narrative — only the trunk the next session needs. Not everything; details are backed by the transcript and git)
</done>

<decisions>
- settled items (must not be reversed)
</decisions>

<pivots>
- ~~previous direction~~ → new direction (reason)
</pivots>

<open>
- open questions, parked discussions
</open>

<blockers>
- things needing external action/confirmation
</blockers>

<todos>
- [ ] work to start right away
</todos>

<files>
- `path/to/file` — what was done (only changes git does not track)
</files>
```

## Section guide

| Tag | Meaning | Content | May be empty? |
|------|------|------|:---:|
| `<done>` | What was done | **Key narrative summary** of this session (the trunk of discussion/implementation/debugging — not an exhaustive list; details are backed by transcript and git) | ❌ required |
| `<decisions>` | Decisions | Settled items. Must not be reversed in the next session | ⭕ omit the tag if none |
| `<pivots>` | Direction changes | What changed direction this session and why | ⭕ omit the tag if none |
| `<open>` | Unresolved | Questions without an answer yet, parked discussions | ⭕ omit the tag if none |
| `<blockers>` | Waiting | Blockers: user action, external confirmation, … | ⭕ omit the tag if none |
| `<todos>` | Next-session TODO | Work to start right away next time. Checkbox form | ❌ required |
| `<files>` | Changes outside git | **Only changes git does not track** — global config (`~/.claude`, `~/.git-hooks`), memory, releases/tags, other repos. Committed repo files are not listed again; `git log --stat` is the source of truth | ⭕ omit the tag if none |

## Body compression (100% information preserved)

Body tags (`<done>`/`<decisions>`/`<open>`/`<todos>` …) are written in **keyword-compressed form, not prose**. The next session's AI agent parsing this log is the top priority, so carrying the same facts in fewer tokens wins. Measured: same log, prose → compressed ≈ **−17%** tokens (beats a full English translation's −13.4%, with zero search/readability cost).

**Two separate axes** — `<done>`'s "key narrative summary" is about *what to include* (information selection); compression is about *how to express what is included* (expression). Compression **only trims expression and never drops facts, decisions or rationale**.

**Rules**:
1. Prose sentences → keywords/bullets. Drop particles, connectives, redundant modifiers
2. Trim expression only; zero loss of facts/decisions/rationale — a loss is a failed compression
3. **Keep verbatim (no abbreviation)** — any string whose form carries meaning stays as written: code identifiers (`OrderListItem`), file paths, commit hashes (`73b9eee`), API paths, numbers/versions, function names + error messages, user quotes, command/log strings
4. Causation with `→` (cause → effect)
5. **Keep the language** of the project (do not translate) — keeps semantic/grep/wiki search consistent
6. Frontmatter is already compact → unchanged

**before/after** (same content):
```
prose:      The partner name was not returned, so the FE partner column was empty; fixed by adding partner_name to OrderListItem
compressed: OrderListItem partner_name missing → FE partner column empty → added partner_name, fixed
```

## Frontmatter field guide

| Field | Content | Search use | Example |
|------|------|------|------|
| `session` | number | identity | `5` |
| `branch` | branch name | identity | `feature-chat` |
| `date` | date | chronological sort/filter | `2026-04-20` |
| `project` | project name (from the current working directory) | project filter | `bohe-session-log` |
| `stage` | stage; fixed 5 values: planning / design / implementation / verification / done | stage filter | `implementation` |
| `tldr` | one-line summary | preview | — |
| `tags` | topic keywords unique to this session | **identify this session (in-folder search)** | `[chat, ui, auth]` |
| `entities` | components/files this session touched | **what this session touched** | `[ChatPanel, useAuth]` |
| `decisions_summary` | list of one-line decision summaries | **decision search** | `[w-[448px] floating fixed, adopt pnpm]` |
| `related_sessions` | list of related earlier session file names/numbers | **link related sessions** | `[feature-chat-00003-2026-04-14]` |

`tags` / `entities` / `decisions_summary` / `related_sessions` are optional but **fill them as fully as possible to maximize searchability**. An empty list `[]` is allowed.

- **tags**: session logs are a closed set searched only within `docs/session-log/`. Carry only **the topics that distinguish this session from the other session logs**. Words common to every session of that project (the project name, skills used every session, …) have no discriminating power — exclude them. Concrete topics + versions, de-duplicated, 3–8 recommended
- **entities**: the components/modules/files/symbols this session centrally touched, by their real names. Prefer **what is specific to this session** over targets repeated every session
- **decisions_summary**: each `<decisions>` item compressed to a short phrase. If the body is empty, leave this field empty too

**decisions_summary domain-prefix rule** (important — `bohe-wiki-sync` updates hub pages from it):
- Each item is `[domain] decision text`. domain = an entry of the project's `.claude/wiki-config.yaml` `domains:` list (auth/partner/order …)
- A decision spanning several domains is split into several items (no compound prefix like `[auth,partner]`). Decisions outside any domain may use `[general]` or omit the prefix
- e.g. `"[auth] JWT 24h + refresh 7d"`, `"[partner] block history append-only"`, `"[general] add coverage gate to CI"`
- Without a prefix the decision is not reflected in the wiki domain hub. The `<decisions>` body is free-form; `decisions_summary` is parsed, so follow the rule

## Update mode (same day · same context)

Never add or delete existing content freely — append in **history form**.
- Add a `### 갱신 {HH:MM or "afternoon session"}` sub-heading at the **inner end** of each XML tag block that receives new content (never outside the tag; tags with nothing to add get no sub-heading). If the draft spans several times, use the latest time and merge everything into one update section
- Draft stubs go into the `<done>` update section; decisions extracted from the conversation are appended at the end of `<decisions>`. Existing `<decisions>`/`<pivots>` are kept
- `<todos>`: strike completed items with `~~strikethrough~~`, then add new ones
- **Never delete existing content** — even wrong content is preserved with `~~strikethrough~~`
- Frontmatter: overwrite `stage`/`tldr` with the current state (progress); **merge existing + new** for `tags`/`entities`/`decisions_summary` (de-duplicate)

## Notes

- Omit empty sections **tag and all** (leave no empty tags)
- No code details — paths and a summary in `<files>` only. **`<files>` records only changes git cannot see** (committed repo files: `git log --stat` is the source of truth)
- **`<decisions>` is the session ADR** — the log holds the full story of each decision (including the why). Only "rules to apply from now on" are promoted to the agent's persistent memory (e.g. `MEMORY.md`) — a hierarchy, not duplication: the log holds the content, memory extracts the rule. Search via frontmatter `decisions_summary`
- **No artifact duplication** — content already in a PRD, plan, ADR, issue, commit or diff is referenced by path/URL (`details: docs/prd/auth.md#token-policy`), never copied into the body. Detailed plans: record the plan's path only
- **XML tags**: lowercase, no underscores, fixed set of the 7 tags above. Always match opening/closing pairs (a mismatch breaks the next session's parsing). Inside a tag, Markdown bullets/checkboxes/strikethrough are all allowed
