# Transcript-based recovery (crash / compaction)

Reference for `bohe-session-log`. The draft holds commit-message stubs only, so when **the session did not end normally (crash) or was compacted mid-way (context compressed)**, the stubs alone give a thin recovery. In that case, use **the conversation transcript left on disk** as raw material. Transcripts stay on disk regardless of compaction (compaction only compresses the context window). The tail just before a crash may be missing, though — do not assume full persistence, and state any missing range in the log.

**Normally unnecessary** — on a normal end the conversation context is still live, so do not read it. Only these two cases trigger it:

| Scenario | When | What to read |
|---|---|---|
| **Compaction** | Session-end Step 2; the session was compacted at some point | **the current session's** transcript |
| **Crash** | Next session start; `bohe-session-start` unfinished-session detection approved | **the previous session's** transcript (any tool) |

## Finding the transcript

Each CLI leaves the conversation on disk. **Compaction** looks only at the running tool's own records. **Crash** looks at **all** the locations below (installed tools only), because the previous session may have run in another tool.

- Candidate search: **cwd (the current working directory, or another worktree path of this repo from `git worktree list`) + most recent modification (mtime)**. Do not settle on mtime alone — cross-check the session id / cwd metadata inside the record. **Compaction** targets the current session's record. **Crash** excludes the current session's record and, **across tools**, among the records whose last activity is later than the current branch's latest log (no lower bound if the branch has no log), **settles on** the most recent one whose raw text contains a stub sha or commit message from the draft that triggered the detection — time alone cannot tell it apart from a normally ended session (its record goes on after the log is written) or a session still running in another worktree. If no record contains one, report candidates only or fall back to degraded mode. Tell the user which tool's record was used. If concurrent sessions or subagents cannot be told apart, report candidates only
- Known location hints:
  - **Claude Code**: `~/.claude/projects/<encoded-cwd>/<session>.jsonl`
  - **Codex**: `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` (under `CODEX_HOME` if set). Match the session via `session_meta.payload.id/cwd` on the first line. Extract only user/assistant message text from `response_item` plus any needed `event_msg`; drop tool results, attachments and duplicate events
  - **Antigravity CLI**: find the `conversationId` via `workspace` (= cwd) in `~/.gemini/antigravity-cli/history.jsonl` → `~/.gemini/antigravity-cli/brain/<conversationId>/.system_generated/logs/transcript_full.jsonl` (activity time = this file's mtime; `history.jsonl` is a shared index, so its mtime is not per session)
  - **Other tools**: locate your CLI's session-record directory and apply the same rule (cwd + newest + stub match)
- Not found → recover from the draft stubs only (degraded mode). Do not guess; tell the user "transcript not found, writing from stubs only". If the record is incomplete, state that range in the log

## Token management (never read the whole thing)

Transcripts can be large (tool calls and results are most of the volume). Bound the cost with:

- **Scope**: only the span after the last formal log (or the last draft stub) — usually one session
- **Filter**: drop tool calls, tool results and attachments, plus **skill-load text** (`Base directory for this skill…`), `<system-reminder>` blocks and slash-command blocks → keep only **user input + assistant text**. Measured on Claude Code: 3.4 MB → 84 KB (≈1/40) while recovery confidence stayed at 92%
- **Delegation**: if a helper worker is available, let it read the transcript and organize done/decisions/pivots/… so **the main context receives only the result** (protects the main token budget)
- Existing summaries (compaction summary, rollout summary) are for scope and flow only. Confirm facts and decisions in the filtered transcript (in the compaction scenario the summary is precisely what lost the details)

Recovery is a **rare event** (only on an unfinished session), so a helper spending tens of thousands of tokens once is acceptable. Normally (normal end) the cost is zero.
