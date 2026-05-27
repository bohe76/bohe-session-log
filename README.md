# bohe-session-log

Persistent session memory for AI coding assistants — log what you did, resume instantly next session.

Works with **Claude Code**, **Cursor**, and **Codex**.

## Install

```bash
git clone https://github.com/bohe76/bohe-session-log
cd bohe-session-log && bash install.sh
```

The installer auto-detects your tools and sets everything up:
- Copies skills to `~/.claude/skills/` (Claude Code) and/or `~/.codex/skills/` (Codex)
- Installs a global git post-commit hook that works across all tools

## What it does

A git hook captures every commit into a rolling draft. At session end, your AI writes a structured log. Next session, it loads the log and picks up exactly where you left off.

```
git commit
  → hook appends stub to draft
  → Claude Code: auto-enriches stub with conversation context

"end session"
  → AI writes formal session log from draft + conversation

"session start" / "where were we"
  → AI loads previous decisions, open questions, and TODOs
  → ready to continue
```

## Skills

| Skill | Trigger | Role |
|-------|---------|------|
| `bohe-session-log` | "end session", "save session", "wrap up" | Writes structured session log |
| `bohe-session-start` | "session start", "where were we", "continue" | Loads previous session context |

Skills are Claude Code native. For Cursor and Codex, the git hook still captures commits — invoke the skill behavior by pasting the SKILL.md content when needed.

## Session log format

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

<done>- ...</done>
<decisions>- ...</decisions>
<todos>- [ ] ...</todos>
```

Logs live in `docs/session-log/` which is gitignored — personal records stay local.

## Files

```
install.sh
skills/
  bohe-session-log/
    SKILL.md
    hooks/
      post-commit.sh       — git hook (installed globally by install.sh)
  bohe-session-start/
    SKILL.md
CHANGELOG.md
```

## License

MIT
