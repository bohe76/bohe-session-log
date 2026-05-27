# bohe-session-log

Claude Code skills for persistent session memory — write logs at session end, resume instantly at session start.

## Overview

Two skills that work together to give Claude a persistent memory across sessions:

| Skill | Role |
|-------|------|
| **bohe-session-log** | Writes a structured session log at the end of each session |
| **bohe-session-start** | Loads the previous session's context at the start of each session |

The log format is designed for AI parsing accuracy first — XML-tagged sections with frontmatter metadata for fast search.

## Installation

Copy the skill directories into your Claude Code global skills folder:

```bash
cp -r skills/bohe-session-log ~/.claude/skills/
cp -r skills/bohe-session-start ~/.claude/skills/
```

Then install the git commit hook that auto-enriches drafts:

```bash
cp skills/bohe-session-log/hooks/post-commit.sh ~/.claude/hooks/draft_checkpoint.sh
chmod +x ~/.claude/hooks/draft_checkpoint.sh
```

Register the hook in `~/.claude/settings.json` — see `skills/bohe-session-log/hooks/settings-snippet.json` for the snippet to add.

## Usage

**At session start** — say any of:
> "session start", "resume work", "continue", "where were we"

Claude loads the previous session's decisions, open questions, and TODOs.

**At session end** — say any of:
> "end session", "save session", "session done", "wrap up"

Claude writes a structured log to `docs/session-log/` with everything needed to resume next time.

**Search past sessions** — say:
> "find sessions about {topic}", "when did we decide {X}"

Claude greps frontmatter only (fast) and presents candidate sessions.

## Log Format

Each session log is a Markdown file with YAML frontmatter and XML-tagged body sections:

```markdown
---
session: 5
branch: main
date: 2026-04-20
stage: implementation
tldr: Added floating chat panel
tags: [chat, ui]
entities: [ChatPanel]
decisions_summary:
  - "[ui] floating panel width w-[448px] fixed"
related_sessions: [main-00004-2026-04-18]
---

# Session 5 — 2026-04-20 (main)

<done>
- ...
</done>

<decisions>
- ...
</decisions>

<todos>
- [ ] ...
</todos>
```

Logs are stored in `docs/session-log/` which is gitignored — personal work records stay local.

## How it works

```
Session end:
  git commit → hook appends stub to draft → enrich mode fills in details
  "end session" → bohe-session-log writes formal log from draft + context

Session start:
  bohe-session-start reads latest log (skips <done>, loads decisions/todos)
  + reads decisions_summary from 2nd most recent log
  → Claude is ready to continue
```

## Files

```
skills/
  bohe-session-log/
    SKILL.md          — skill definition
    hooks/
      post-commit.sh        — git hook version
      settings-snippet.json — Claude Code hook config snippet
  bohe-session-start/
    SKILL.md          — skill definition
CHANGELOG.md
```

## License

MIT
