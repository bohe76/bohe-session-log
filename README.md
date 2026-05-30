# bohe-session-log

Persistent session memory for AI coding assistants — log what you did, resume instantly next session.

Works on **macOS / Linux / Windows** with **Claude Code**, **Codex**, **Cursor**, **Gemini CLI**, and **Antigravity CLI**.

## Install

**macOS / Linux / Windows (Git Bash):**

```bash
git clone https://github.com/bohe76/bohe-session-log
cd bohe-session-log && bash install.sh
```

**Windows (native PowerShell):**

```powershell
git clone https://github.com/bohe76/bohe-session-log
cd bohe-session-log; pwsh -ExecutionPolicy Bypass -File install.ps1
```

The installer:

- Copies skills to each detected tool's skills directory (Claude Code, Codex, Cursor, Gemini CLI, Antigravity CLI)
- Copies the hook script to a stable location (`~/.bohe-session-log/`) so deleting the cloned repo doesn't break it
- Installs a `post-commit` git hook that **respects your existing `core.hooksPath`** and **appends to any existing hook** rather than overwriting

### Verify

```bash
cd <any git repo>
git commit --allow-empty -m "test hook"
cat docs/session-log/<branch>.draft.md   # should contain a stub entry
```

If you see `## [HH:MM] test hook ...`, the hook is working.

## Requirements

- `git` 2.9+
- `bash` (Git Bash on Windows is fine) OR PowerShell 5.1+ for `install.ps1`
- One of: Claude Code, Codex, Cursor, Gemini CLI, or Antigravity CLI (optional — the hook works without any AI tool)

## What it does

A git hook captures every commit into a rolling draft. At session end, your AI writes a structured log. Next session, it loads the log and picks up exactly where you left off.

```
git commit
  → hook appends a commit-message stub to docs/session-log/session.draft.md

"end session" / "save session"
  → AI writes a formal session log from draft + conversation

"session start" / "where were we"
  → AI loads previous decisions, open questions, and TODOs
  → ready to continue
```

## Skills

| Skill | Trigger | Role |
|-------|---------|------|
| `bohe-session-log` | `"end session"`, `"save session"`, `"wrap up"`, `"세션 종료"` | Writes structured session log |
| `bohe-session-start` | `"session start"`, `"where were we"`, `"continue"`, `"세션 시작"`, `"업무 준비"` | Loads previous session context |

### Tool support matrix

| Tool | Skill auto-trigger | Git hook capture |
|------|:-:|:-:|
| Claude Code | ✓ | ✓ |
| Codex | ✓ | ✓ |
| Cursor | ✓ | ✓ |
| Gemini CLI | ✓ | ✓ |
| Antigravity CLI | ✓ | ✓ |

### Skill install locations

| Tool | Global skills directory |
|------|------------------------|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Cursor | `~/.cursor/skills/` |
| Gemini CLI | `~/.gemini/skills/` |
| Antigravity CLI | `~/.antigravity/skills/` |

The installer auto-detects which tools are present and copies skills to each directory.

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
<pivots>- ...</pivots>
<open>- ...</open>
<blockers>- ...</blockers>
<todos>- [ ] ...</todos>
<files>- path/to/file.ts — what changed</files>
```

Logs live in `docs/session-log/` which is gitignored — personal records stay local.

## Uninstall

```bash
bash uninstall.sh         # macOS / Linux / Git Bash
pwsh -ExecutionPolicy Bypass -File uninstall.ps1   # Windows PowerShell
```

Removes skills, the stable hook script, and the delegation line in your `post-commit` hook. **Does not** touch your `core.hooksPath` setting or any session logs in your projects.

## Troubleshooting

**Hook doesn't fire after commit**

```bash
git config --global core.hooksPath        # should point to a directory
ls "$(git config --global core.hooksPath)/post-commit"   # file must exist and be executable
```

**Windows: `bash: command not found` when committing**

Git for Windows ships with bash — ensure Git is installed and the post-commit file uses LF line endings (the installers handle this automatically).

**Hook fires but no draft appears**

Make sure you're in a git repo (`git rev-parse --show-toplevel` must succeed) and on a branch (not detached HEAD).

**Existing `core.hooksPath` was already set**

The installer preserves it and installs into that same directory. If you later remove `bohe-session-log`, your existing setup remains intact.

## Files

```
install.sh / install.ps1        — installers
uninstall.sh / uninstall.ps1    — uninstallers
skills/
  bohe-session-log/
    SKILL.md
    hooks/
      post-commit.sh            — copied to ~/.bohe-session-log/ by installer
  bohe-session-start/
    SKILL.md
CHANGELOG.md
LICENSE
```

## Contributing

Issues and PRs welcome. See `.github/` for templates.

## License

MIT — see [LICENSE](LICENSE).
