# bohe-session-log installer (Windows / PowerShell 5.1+)
# Supports: Claude Code, Codex, Cursor, Gemini CLI, Antigravity CLI, and any git-based workflow.
#
# Design mirrors install.sh:
#   - Hook script copied to a STABLE location (~/.bohe-session-log/)
#   - Existing core.hooksPath is RESPECTED
#   - Existing post-commit hook is APPENDED to, not overwritten
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

$SkillsInstalled = 0

Write-Host 'bohe-session-log installer'
Write-Host '=========================='

# ── 1. Copy hook to stable location ─────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $StableDir | Out-Null
Copy-Item -Force $HookSrcRepo $StableHook
Write-Host "OK  Hook script  -> $StableHook"

# ── 2. Skills: Claude Code ──────────────────────────────────────────────────
$ClaudeDir = Join-Path $HOME '.claude'
if (Test-Path $ClaudeDir) {
  $Target = Join-Path $ClaudeDir 'skills'
  New-Item -ItemType Directory -Force -Path $Target | Out-Null
  Copy-Item -Recurse -Force (Join-Path $SkillsSrc 'bohe-session-log')   $Target
  Copy-Item -Recurse -Force (Join-Path $SkillsSrc 'bohe-session-start') $Target
  Write-Host "OK  Claude Code  -> $Target"
  $SkillsInstalled++
}

# ── 3. Skills: Codex ────────────────────────────────────────────────────────
$CodexDir = Join-Path $HOME '.codex'
if (Test-Path $CodexDir) {
  $Target = Join-Path $CodexDir 'skills'
  New-Item -ItemType Directory -Force -Path $Target | Out-Null
  Copy-Item -Recurse -Force (Join-Path $SkillsSrc 'bohe-session-log')   $Target
  Copy-Item -Recurse -Force (Join-Path $SkillsSrc 'bohe-session-start') $Target
  Write-Host "OK  Codex        -> $Target"
  $SkillsInstalled++
}

# ── 4. Skills: Cursor ───────────────────────────────────────────────────────
$CursorDir = Join-Path $HOME '.cursor'
if (Test-Path $CursorDir) {
  $Target = Join-Path $CursorDir 'skills'
  New-Item -ItemType Directory -Force -Path $Target | Out-Null
  Copy-Item -Recurse -Force (Join-Path $SkillsSrc 'bohe-session-log')   $Target
  Copy-Item -Recurse -Force (Join-Path $SkillsSrc 'bohe-session-start') $Target
  Write-Host "OK  Cursor       -> $Target"
  $SkillsInstalled++
}

# ── 5. Skills: Gemini CLI ───────────────────────────────────────────────────
$GeminiDir = Join-Path $HOME '.gemini'
if (Test-Path $GeminiDir) {
  $Target = Join-Path $GeminiDir 'skills'
  New-Item -ItemType Directory -Force -Path $Target | Out-Null
  Copy-Item -Recurse -Force (Join-Path $SkillsSrc 'bohe-session-log')   $Target
  Copy-Item -Recurse -Force (Join-Path $SkillsSrc 'bohe-session-start') $Target
  Write-Host "OK  Gemini CLI   -> $Target"
  $SkillsInstalled++
}

# ── 6. Skills: Antigravity CLI ──────────────────────────────────────────────
$AntigravityDir = Join-Path $HOME '.antigravity'
if (Test-Path $AntigravityDir) {
  $Target = Join-Path $AntigravityDir 'skills'
  New-Item -ItemType Directory -Force -Path $Target | Out-Null
  Copy-Item -Recurse -Force (Join-Path $SkillsSrc 'bohe-session-log')   $Target
  Copy-Item -Recurse -Force (Join-Path $SkillsSrc 'bohe-session-start') $Target
  Write-Host "OK  Antigravity  -> $Target"
  $SkillsInstalled++
}

# ── 7. Git hook — respect existing config, append don't overwrite ───────────
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
  Write-Host 'WARN  No supported AI tool detected (~/.claude / ~/.codex / ~/.cursor / ~/.gemini / ~/.antigravity).'
  Write-Host '      Skills were not installed. Git hook works regardless of AI tool.'
} else {
  Write-Host 'Done. Restart your AI tool to activate the skills.'
}

Write-Host ''
Write-Host 'Quick test:'
Write-Host '  cd <any git repo>; git commit --allow-empty -m "test hook"'
Write-Host '  Get-Content docs/session-log/<branch>.draft.md   # should have one stub entry'
Write-Host ''
Write-Host 'Triggers:'
Write-Host "  bohe-session-log   — 'end session', 'save session', '세션 종료'"
Write-Host "  bohe-session-start — 'session start', 'where were we', '세션 시작'"
