# bohe-session-log installer (Windows / PowerShell 5.1+)
# Supports: Claude Code, Codex, Cursor, Antigravity CLI, Grok, and any git-based workflow.
#
# Design mirrors install.sh:
#   - Hook script copied to a STABLE location (~/.bohe-session-log/)
#   - Existing core.hooksPath is RESPECTED
#   - Existing post-commit hook is APPENDED to, not overwritten
#   - Skills are installed only for tools detected on this machine
#   - An existing skill folder (or junction) is replaced, never nested into
#
# Usage (in PowerShell):
#   pwsh -ExecutionPolicy Bypass -File install.ps1
#   # or
#   powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = 'Stop'

$RepoDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSrc = Join-Path $RepoDir 'skills'
$HookSrcRepo = Join-Path $SkillsSrc 'bohe-session-log\hooks\post-commit.sh'

# Stable hook location
$StableDir  = Join-Path $HOME '.bohe-session-log'
$StableHook = Join-Path $StableDir 'post-commit.sh'

$SkillNames = @('bohe-session-log', 'bohe-session-start')
$SkillsInstalled = 0

# Tool -> (detect dir, skills dir). Skills go only where the tool exists.
$Tools = @(
  @{ Label = 'Claude Code'; Detect = (Join-Path $HOME '.claude');                Skills = (Join-Path $HOME '.claude\skills') },
  @{ Label = 'Codex';       Detect = (Join-Path $HOME '.codex');                 Skills = (Join-Path $HOME '.codex\skills') },
  @{ Label = 'Cursor';      Detect = (Join-Path $HOME '.cursor');                Skills = (Join-Path $HOME '.cursor\skills') },
  @{ Label = 'Antigravity'; Detect = (Join-Path $HOME '.gemini\antigravity-cli'); Skills = (Join-Path $HOME '.gemini\antigravity-cli\skills') },
  @{ Label = 'Grok';        Detect = (Join-Path $HOME '.grok');                  Skills = (Join-Path $HOME '.grok\skills') }
)

function Remove-ExistingSkill {
  param([string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.LinkType) {
    # Junction / symlink: delete the link itself, never follow it into the target.
    $item.Delete()
  } else {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
}

function Install-Skills {
  param([string] $Target, [string] $Label)
  New-Item -ItemType Directory -Force -Path $Target | Out-Null
  foreach ($name in $SkillNames) {
    $dest = Join-Path $Target $name
    # Copy-Item -Recurse into an existing folder nests a second copy inside it;
    # replace the folder instead so re-running the installer stays idempotent.
    Remove-ExistingSkill $dest
    Copy-Item -Recurse -Force (Join-Path $SkillsSrc $name) $dest
  }
  Write-Host ("OK  {0,-12} -> {1}" -f $Label, $Target)
}

Write-Host 'bohe-session-log installer'
Write-Host '=========================='

# ── 1. Copy hook to stable location ─────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $StableDir | Out-Null
Copy-Item -Force $HookSrcRepo $StableHook
Write-Host "OK  Hook script  -> $StableHook"

# ── 2. Skills: one copy per detected tool ───────────────────────────────────
foreach ($tool in $Tools) {
  if (Test-Path -LiteralPath $tool.Detect) {
    Install-Skills -Target $tool.Skills -Label $tool.Label
    $SkillsInstalled++
  }
}

# ── 3. Git hook — respect existing config, append don't overwrite ───────────
$ExistingHooksPath = $null
try { $ExistingHooksPath = git config --global --get core.hooksPath 2>$null } catch {}
if ([string]::IsNullOrWhiteSpace($ExistingHooksPath)) {
  $HookDir = Join-Path $HOME '.git-hooks'
  $HookDirIsNew = $true
} else {
  # Normalize ~ and forward slashes
  $HookDir = $ExistingHooksPath -replace '^~', $HOME
  $HookDir = $HookDir -replace '/', '\'
  $HookDirIsNew = $false
  Write-Host "    Detected existing core.hooksPath -> $HookDir (preserving)"
}

New-Item -ItemType Directory -Force -Path $HookDir | Out-Null

$ExistingHook = Join-Path $HookDir 'post-commit'
$Marker = '# bohe-session-log: post-commit draft capture'

# Hook bodies need forward-slash style POSIX path for Git Bash on Windows
$StableHookPosix = $StableHook -replace '\\', '/'
$StableHookPosix = $StableHookPosix -replace '^([A-Z]):', { '/' + $args[0].Groups[1].Value.ToLower() }

if (Test-Path $ExistingHook) {
  $content = Get-Content -Raw -Path $ExistingHook
  if ($content -match 'bohe-session-log') {
    Write-Host "OK  Git hook     -> already installed in $ExistingHook (skipped)"
  } else {
    Add-Content -Path $ExistingHook -Value ""
    Add-Content -Path $ExistingHook -Value $Marker
    Add-Content -Path $ExistingHook -Value "bash `"$StableHookPosix`""
    Write-Host "OK  Git hook     -> appended to existing $ExistingHook"
  }
} else {
  $hookContent = @"
#!/bin/bash
$Marker
bash "$StableHookPosix"
"@
  # Write LF line endings — git hooks run via bash and CRLF can break them
  [System.IO.File]::WriteAllText($ExistingHook, ($hookContent -replace "`r`n", "`n"))
  Write-Host "OK  Git hook     -> $ExistingHook"
}

if ($HookDirIsNew) {
  git config --global core.hooksPath $HookDir | Out-Null
  Write-Host "OK  Git config   -> core.hooksPath=$HookDir"
}

# ── Summary ─────────────────────────────────────────────────────────────────
Write-Host ''
if ($SkillsInstalled -eq 0) {
  Write-Host 'WARN  No supported AI tool detected (~/.claude / ~/.codex / ~/.cursor / ~/.gemini/antigravity-cli / ~/.grok).'
  Write-Host '      Skills were not installed. Git hook works regardless of AI tool.'
} else {
  Write-Host 'Done. Restart your AI tool to activate the skills.'
}

Write-Host ''
Write-Host 'Note: a repo-local core.hooksPath (husky, .githooks, ...) shadows the global hook.'
Write-Host '      See skills/bohe-session-log/references/hook_setup.md for the 2-line chain call.'
Write-Host ''
Write-Host 'Quick test (in a repo that has docs/session-log/ — create it to opt in):'
Write-Host '  New-Item -ItemType Directory -Force docs/session-log | Out-Null'
Write-Host '  git commit --allow-empty -m "test hook"'
Write-Host '  Get-Content docs/session-log/drafts/<branch>.draft.md   # should have one stub entry'
Write-Host ''
Write-Host 'Triggers:'
Write-Host "  bohe-session-log   — 'end session', 'save session', '세션 종료'"
Write-Host "  bohe-session-start — 'session start', 'where were we', '세션 시작'"
