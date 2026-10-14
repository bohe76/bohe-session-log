# bohe-session-log

**English** | [한국어](README.ko.md)

**Persistent memory for AI coding agents — your next session picks up exactly where the last one left off.**

AI coding agents forget everything when a session ends. You burn the first 20 minutes re-explaining what you built, what you decided, and what's still open — and the agent *still* repeats mistakes you already ruled out.

**bohe-session-log** ends every session with a structured, searchable log that the *next* session reads automatically — decisions, pivots, open questions, and TODOs, restored in seconds. Just a git hook plus two skills; no database, no service, no lock-in.

Works on **macOS / Linux / Windows** with **Claude Code**, **Codex**, **Cursor**, **Antigravity CLI**, and **Grok**. One tool-neutral `SKILL.md` per skill — the same file is installed for every tool, with no per-tool branches.

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

- Copies the skills to each **detected** tool's skills directory (Claude Code, Codex, Cursor, Antigravity CLI, Grok) — tools that aren't installed are skipped
- Replaces an existing skill folder (or symlink/junction) in place, so re-running is idempotent
- Copies the hook script to a stable location (`~/.bohe-session-log/`) so deleting the cloned repo doesn't break it
- Installs a `post-commit` git hook that **respects your existing `core.hooksPath`** and **appends to any existing hook** rather than overwriting

### Verify

The hook is opt-in per repository: it only fires where `docs/session-log/` exists.

```bash
cd <any git repo>
mkdir -p docs/session-log
git commit --allow-empty -m "test hook"
cat docs/session-log/drafts/<branch>.draft.md   # should contain a stub entry
```

If you see `## [HH:MM] test hook <!-- sha:… branch:… -->`, the hook is working.

## Requirements

- `git` 2.31+ (`git branch --show-current`, `git rev-parse --path-format`)
- `bash` (Git Bash on Windows is fine) OR PowerShell 5.1+ for `install.ps1`
- One of: Claude Code, Codex, Cursor, Antigravity CLI, or Grok (optional — the hook works without any AI tool)

## What it does

A git hook captures every commit into a rolling draft. At session end, your AI writes a structured log. Next session, it loads the log and picks up exactly where you left off.

```
git commit
  → hook appends a commit-message stub to docs/session-log/drafts/<branch>.draft.md

"end session" / "save session"
  → AI writes a formal session log from draft + conversation, then deletes the draft

"session start" / "where were we"
  → AI loads the last session's decisions, open questions, and TODOs (any branch)
  → plus what other branches / worktrees did since (frontmatter only)
  → ready to continue
```

### Branches and worktrees

There is **one store per repository**: the `docs/session-log/` of the **main worktree**. Linked worktrees write their drafts and logs there too, so nothing is lost when a worktree is removed, and a session on `main` sees every branch's logs. Logs are named per branch (`<branch>-<number>-<date>.md`, numbering independent per branch) and drafts are one file per branch (`drafts/<branch>.draft.md`), so concurrent worktrees never write to the same file.

**Session start always continues from the last session log, whichever branch it was written on**, and a single session end is enough even if the session committed to several branches: it folds in every draft nobody can still write to — a branch checked out in no worktree — tagged `inflow <branch>(merged|not merged)`. Only drafts of branches checked out in another worktree (in progress) or carrying hand-written notes are left alone. That covers all three common setups: everything on `main`; `main` as home with occasional branches; or one lead session on `dev` while agents commit in throwaway worktrees and each PR is merged and its branch deleted.

## Skills

| Skill | Trigger | Role |
|-------|---------|------|
| `bohe-session-log` | `"end session"`, `"save session"`, `"wrap up"`, `"세션 종료"` | Writes structured session log |
| `bohe-session-start` | `"session start"`, `"where were we"`, `"continue"`, `"세션 시작"`, `"업무 준비"` | Loads previous session context |

Rarely needed procedures live next to the skill in `references/` and are read only when triggered:

| File | When the agent reads it |
|------|------------------------|
| `bohe-session-log/references/transcript_recovery.md` | The session was compacted or the previous session crashed — rebuild from the on-disk conversation transcript |
| `bohe-session-log/references/hook_setup.md` | You explicitly ask to install/verify the hook, or a repo-local `core.hooksPath` (husky, `.githooks`) shadows the global hook |

### Tool support matrix

| Tool | Skill auto-trigger | Git hook capture |
|------|:-:|:-:|
| Claude Code | ✓ | ✓ |
| Codex | ✓ | ✓ |
| Cursor | ✓ | ✓ |
| Antigravity CLI | ✓ | ✓ |
| Grok | ✓ | ✓ |

### Skill install locations

| Tool | Global skills directory |
|------|------------------------|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Cursor | `~/.cursor/skills/` |
| Antigravity CLI | `~/.gemini/antigravity-cli/skills/` |
| Grok | `~/.grok/skills/` |

The installer auto-detects which tools are present and copies the skills to each directory.

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

Logs live in `docs/session-log/` of the main worktree, which is gitignored — personal records stay local and must stay untracked (a tracked log gets its mtime bumped on every checkout and breaks "latest log" ordering).

## Uninstall

```bash
bash uninstall.sh         # macOS / Linux / Git Bash
pwsh -ExecutionPolicy Bypass -File uninstall.ps1   # Windows PowerShell
```

Removes the skills from every supported tool directory, the stable hook script, and the delegation line in your `post-commit` hook. **Does not** touch your `core.hooksPath` setting or any session logs in your projects.

## Troubleshooting

**Hook doesn't fire after commit**

```bash
git config --global core.hooksPath        # should point to a directory
ls "$(git config --global core.hooksPath)/post-commit"   # file must exist and be executable
```

**Hook doesn't fire in one specific repo (husky, `.githooks`, …)**

A repo-local `core.hooksPath` (`git config --local core.hooksPath`) shadows the global hook entirely. Add a two-line chain call to that repo's own `post-commit` — see `skills/bohe-session-log/references/hook_setup.md`.

**Windows: `bash: command not found` when committing**

Git for Windows ships with bash — ensure Git is installed and the post-commit file uses LF line endings (the installers handle this automatically).

**Hook fires but no draft appears**

Make sure `docs/session-log/` exists in that repo (the hook is opt-in), you're in a git repo (`git rev-parse --show-toplevel` must succeed), and on a branch (not detached HEAD).

**Existing `core.hooksPath` was already set**

The installer preserves it and installs into that same directory. If you later remove `bohe-session-log`, your existing setup remains intact.

## Files

```
install.sh / install.ps1        — installers
uninstall.sh / uninstall.ps1    — uninstallers
skills/
  bohe-session-log/
    SKILL.md
    references/
      transcript_recovery.md    — crash / compaction recovery procedure
      hook_setup.md             — hook install, verify, repo-local hooksPath chaining, legacy draft migration
    hooks/
      post-commit.sh            — copied to ~/.bohe-session-log/ by installer
  bohe-session-start/
    SKILL.md
tests/
  draft_handoff_test.sh         — regression test for draft handoff and global-latest loading (bash, temp repo)
README.md / README.ko.md        — English / Korean
CHANGELOG.md
LICENSE
```

## Contributing

Issues and PRs welcome. See `.github/` for templates.

## License

MIT — see [LICENSE](LICENSE).
