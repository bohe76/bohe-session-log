# bohe-session-log

[English](README.md) | **한국어**

**AI 코딩 에이전트를 위한, 세션을 넘어 이어지는 기억 — 다음 세션이 지난 세션이 멈춘 바로 그 자리에서 이어갑니다.**

AI 코딩 에이전트는 세션이 끝나면 모든 것을 잊습니다. 무엇을 만들었고, 무엇을 결정했고, 무엇이 아직 열려 있는지 다시 설명하느라 처음 20분을 쓰고, 그래도 에이전트는 이미 배제한 실수를 *또* 반복합니다.

**bohe-session-log**는 세션마다 구조화되고 검색 가능한 로그를 남기고, *다음* 세션이 그것을 자동으로 읽습니다 — 결정, 방향 전환, 열린 질문, TODO가 몇 초 만에 복원됩니다. git 훅 하나와 스킬 두 개가 전부이고, 데이터베이스도 서비스도 특정 벤더 종속도 없습니다.

**macOS / Linux / Windows**에서 **Claude Code**, **Codex**, **Cursor**, **Antigravity CLI**, **Grok**과 함께 동작합니다. 스킬마다 툴 중립 `SKILL.md` 하나 — 모든 툴에 같은 파일이 설치되며 툴별 분기가 없습니다.

## 설치

**macOS / Linux / Windows (Git Bash):**

```bash
git clone https://github.com/bohe76/bohe-session-log
cd bohe-session-log && bash install.sh
```

**Windows (네이티브 PowerShell):**

```powershell
git clone https://github.com/bohe76/bohe-session-log
cd bohe-session-log; pwsh -ExecutionPolicy Bypass -File install.ps1
```

설치 스크립트는:

- **감지된** 툴의 스킬 디렉토리(Claude Code, Codex, Cursor, Antigravity CLI, Grok)에 스킬을 복사합니다 — 설치되지 않은 툴은 건너뜁니다
- 기존 스킬 폴더(또는 symlink/junction)를 제자리에서 교체하므로 다시 실행해도 결과가 같습니다
- 훅 스크립트를 고정 위치(`~/.bohe-session-log/`)에 복사해, clone한 리포를 지워도 깨지지 않습니다
- `post-commit` git 훅을 설치하되 **기존 `core.hooksPath`를 존중**하고, 기존 훅이 있으면 덮어쓰지 않고 **뒤에 덧붙입니다**

### 확인

훅은 리포마다 opt-in입니다: `docs/session-log/`가 있는 곳에서만 동작합니다.

```bash
cd <any git repo>
mkdir -p docs/session-log
git commit --allow-empty -m "test hook"
cat docs/session-log/drafts/<branch>.draft.md   # should contain a stub entry
```

`## [HH:MM] test hook <!-- sha:… branch:… -->`가 보이면 훅이 동작하는 것입니다.

## 요구 사항

- `git` 2.31+ (`git branch --show-current`, `git rev-parse --path-format`)
- `bash`(Windows는 Git Bash로 충분) 또는 `install.ps1`용 PowerShell 5.1+
- Claude Code, Codex, Cursor, Antigravity CLI, Grok 중 하나(선택 — 훅은 AI 툴 없이도 동작)

## 하는 일

git 훅이 커밋마다 누적 draft에 기록합니다. 세션을 끝낼 때 AI가 구조화된 로그를 씁니다. 다음 세션에서 그 로그를 읽고 멈춘 자리에서 그대로 이어갑니다.

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

### 브랜치와 워크트리

**저장소는 리포당 하나**입니다: **메인 워크트리**의 `docs/session-log/`. linked worktree도 draft와 로그를 그곳에 쓰므로, 워크트리를 지워도 아무것도 잃지 않고 `main`의 세션이 모든 브랜치의 로그를 봅니다. 로그 이름에는 브랜치가 들어가고(`<branch>-<number>-<date>.md`, 번호는 브랜치마다 독립), draft는 브랜치마다 파일 하나(`drafts/<branch>.draft.md`)라 동시에 도는 워크트리가 같은 파일에 쓰는 일이 없습니다.

**세션 시작은 어느 브랜치에서 쓰였든 항상 마지막 세션 로그에서 이어갑니다.** 한 세션이 여러 브랜치에 커밋했어도 세션 종료는 한 번이면 됩니다: 더 이상 아무도 쓸 수 없는 draft(어느 워크트리에도 체크아웃되지 않은 브랜치의 draft)를 모두 `inflow <branch>(merged|not merged)` 표기로 흡수합니다. 다른 워크트리에 체크아웃된 브랜치(진행 중)나 사람이 쓴 메모가 있는 draft만 그대로 둡니다. 흔한 세 가지 구성을 모두 다룹니다: 전부 `main`에서 작업, `main`을 기본으로 두고 가끔 브랜치, 또는 `dev`에 머무는 리드 세션 하나 옆에서 에이전트들이 임시 워크트리에 커밋하고, PR마다 병합한 뒤 브랜치를 지우는 방식.

## 스킬

| 스킬 | 트리거 | 역할 |
|-------|---------|------|
| `bohe-session-log` | `"end session"`, `"save session"`, `"wrap up"`, `"세션 종료"` | 구조화된 세션 로그 작성 |
| `bohe-session-start` | `"session start"`, `"where were we"`, `"continue"`, `"세션 시작"`, `"업무 준비"` | 이전 세션 맥락 로드 |

드물게 필요한 절차는 스킬 옆 `references/`에 있고, 해당할 때만 읽습니다:

| 파일 | 에이전트가 읽는 때 |
|------|------------------------|
| `bohe-session-log/references/transcript_recovery.md` | 세션이 컴팩트됐거나 직전 세션이 크래시함 — 디스크의 대화 트랜스크립트로 복원 |
| `bohe-session-log/references/hook_setup.md` | 훅 설치·확인을 명시적으로 요청했거나, repo-local `core.hooksPath`(husky, `.githooks`)가 전역 훅을 가릴 때 |

### 툴 지원 표

| 툴 | 스킬 자동 트리거 | git 훅 기록 |
|------|:-:|:-:|
| Claude Code | ✓ | ✓ |
| Codex | ✓ | ✓ |
| Cursor | ✓ | ✓ |
| Antigravity CLI | ✓ | ✓ |
| Grok | ✓ | ✓ |

### 스킬 설치 위치

| 툴 | 전역 스킬 디렉토리 |
|------|------------------------|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Cursor | `~/.cursor/skills/` |
| Antigravity CLI | `~/.gemini/antigravity-cli/skills/` |
| Grok | `~/.grok/skills/` |

설치 스크립트가 어떤 툴이 있는지 자동으로 감지해 각 디렉토리에 스킬을 복사합니다.

## 세션 로그 형식

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

로그는 메인 워크트리의 `docs/session-log/`에 있고 gitignore됩니다 — 개인 기록은 로컬에 남고, 반드시 git 추적 밖에 둬야 합니다(추적 중인 로그는 체크아웃할 때마다 mtime이 바뀌어 "최신 로그" 순서가 깨집니다).

## 제거

```bash
bash uninstall.sh         # macOS / Linux / Git Bash
pwsh -ExecutionPolicy Bypass -File uninstall.ps1   # Windows PowerShell
```

지원하는 모든 툴 디렉토리의 스킬, 고정 위치의 훅 스크립트, `post-commit` 훅의 위임 줄을 지웁니다. `core.hooksPath` 설정과 프로젝트의 세션 로그는 **건드리지 않습니다**.

## 문제 해결

**커밋 후 훅이 동작하지 않음**

```bash
git config --global core.hooksPath        # should point to a directory
ls "$(git config --global core.hooksPath)/post-commit"   # file must exist and be executable
```

**특정 리포에서만 훅이 동작하지 않음(husky, `.githooks`, …)**

repo-local `core.hooksPath`(`git config --local core.hooksPath`)는 전역 훅을 통째로 가립니다. 그 리포의 `post-commit`에 두 줄짜리 체인 호출을 추가하세요 — `skills/bohe-session-log/references/hook_setup.md` 참고.

**Windows: 커밋할 때 `bash: command not found`**

Git for Windows에는 bash가 들어 있습니다 — Git이 설치돼 있는지, post-commit 파일이 LF 줄바꿈인지 확인하세요(설치 스크립트가 자동으로 처리합니다).

**훅은 동작하는데 draft가 안 생김**

그 리포에 `docs/session-log/`가 있는지(훅은 opt-in), git 리포 안인지(`git rev-parse --show-toplevel`이 성공해야 함), 브랜치 위인지(detached HEAD가 아닌지) 확인하세요.

**`core.hooksPath`가 이미 설정돼 있었음**

설치 스크립트는 그 설정을 유지하고 같은 디렉토리에 설치합니다. 나중에 `bohe-session-log`를 지워도 기존 구성은 그대로 남습니다.

## 파일

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

## 기여

이슈와 PR을 환영합니다. 템플릿은 `.github/`에 있습니다.

## 라이선스

MIT — [LICENSE](LICENSE) 참고.
