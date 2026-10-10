# Installing and verifying the git post-commit hook

Reference for `bohe-session-log`. Session end and hook installation are separate. **Do not install at session end** — the formal log can be written from the conversation context without any hook. Follow this document only when the user explicitly asks to install or verify the hook.

## How it works

`hooks/post-commit.sh` in this skill's folder is the hook body. `core.hooksPath` points to a global directory (`~/.git-hooks`) so that **commits from every repo and every tool (Claude Code / Codex / Cursor / Antigravity / Grok / …)** run the same hook. Safeguards are built in:

- **Opt-in guard**: fires only in repos that have `docs/session-log/`. Other repos are a no-op (no global pollution)
- **Duplicate-SHA guard**: skips if the commit is already in the draft (including commit retries)
- **Meta-commit filter**: skips commits that only changed `docs/session-log/*`

No LLM is involved. Only what git knows (time, commit message, SHA, branch) is appended to `docs/session-log/session.draft.md`. On Windows, Git for Windows' `sh` runs it as is — no PowerShell port needed.

⚠️ Setting a global `core.hooksPath` **disables `.git/hooks/*` in every repo**. Anything relying on repo-local hooks (git-lfs hooks, for example) stops running, and the pre-commit framework refuses to install. Tell the user before installing and, where needed, keep both via the chain call below.

## Install (only on explicit request)

First check the current state, read-only:

```bash
git config --show-origin --get-all core.hooksPath   # who owns the effective hooks path
ls -l ~/.git-hooks/post-commit                       # existing global hook
```

Install only when **all four** hold: ① no local `core.hooksPath`, ② no global `core.hooksPath`, ③ no `~/.git-hooks/post-commit`, ④ `hooks/post-commit.sh` exists in this skill's folder. If any fails, do not install (never overwrite or disable an existing global/local hook) — check whether it can be merged and agree with the user.

```bash
mkdir -p ~/.git-hooks
cp "<this skill's folder>/hooks/post-commit.sh" ~/.git-hooks/post-commit
chmod +x ~/.git-hooks/post-commit
git config --global core.hooksPath ~/.git-hooks
```

Verify: in a repo that has `docs/session-log/`, make one real commit and confirm a stub `## [HH:MM] <commit message> <!-- sha:… branch:… -->` appeared in `session.draft.md`. Do not create empty commits just for verification.

## Repos with a local `core.hooksPath` (husky, `.githooks`, …)

If the repo's `.git/config` sets `core.hooksPath`, **the global hook is shadowed entirely** — the local setting wins over the global one. In such repos, make the local hook directory's `post-commit` **chain-call** the global hook. Call it; do not copy its body (a copy drifts whenever the global hook changes):

```sh
#!/bin/sh
# Chain-call the global bohe-session-log post-commit hook. No repo-specific logic here.
hook="$HOME/.git-hooks/post-commit"
[ -f "$hook" ] && bash "$hook"
exit 0
```

With husky this goes in `.husky/post-commit`; with a `.githooks` layout, in `.githooks/post-commit`. Make the file executable (`chmod +x` — otherwise git on macOS/Linux ignores the hook). If a post-commit already has content, insert the chain call **before any `exit`/`exec` line** in it (appended after one, it would never run).

## Keeping copies consistent

The hook body must be identical in three places: `hooks/post-commit.sh` in this skill folder (reference), the installed `~/.git-hooks/post-commit`, and `hooks/post-commit.sh` inside the skill folders copied to other tools' directories. After changing the reference, update the installed copy too.
