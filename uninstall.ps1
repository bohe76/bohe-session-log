# bohe-session-log uninstaller (Windows / PowerShell 5.1+)
#
# Mirrors uninstall.sh — removes skills, stable hook, and hook delegation lines.
# Preserves: core.hooksPath, user's other hooks, project session logs.
#
# Usage:
#   pwsh -ExecutionPolicy Bypass -File uninstall.ps1

$ErrorActionPreference = 'Stop'

$StableDir = Join-Path $HOME '.bohe-session-log'
$SkillNames = @('bohe-session-log', 'bohe-session-start')
$SkillDirs = @(
  (Join-Path $HOME '.claude\skills'),
  (Join-Path $HOME '.codex\skills'),
  (Join-Path $HOME '.cursor\skills'),
  (Join-Path $HOME '.gemini\antigravity-cli\skills'),
  (Join-Path $HOME '.grok\skills')
)

function Remove-ExistingSkill {
  param([string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.LinkType) {
    # Junction / symlink: delete the link itself, never follow it into the target.
    $item.Delete()
  } else {
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
  return $true
}

Write-Host 'bohe-session-log uninstaller'
Write-Host '============================'

# ── 1. Skills ──────────────────────────────────────────────────────────────
foreach ($target in $SkillDirs) {
  $removed = $false
  foreach ($name in $SkillNames) {
    if (Remove-ExistingSkill (Join-Path $target $name)) { $removed = $true }
  }
  if ($removed) { Write-Host "OK  Skills       -> removed from $target" }
}

# ── 2. Hook delegation in post-commit ──────────────────────────────────────
$hooksPath = $null
try { $hooksPath = git config --global --get core.hooksPath 2>$null } catch {}
if ([string]::IsNullOrWhiteSpace($hooksPath)) {
  $hooksPath = Join-Path $HOME '.git-hooks'
} else {
  $hooksPath = $hooksPath -replace '^~', $HOME
  $hooksPath = $hooksPath -replace '/', '\'
}

$postCommit = Join-Path $hooksPath 'post-commit'
if (Test-Path $postCommit) {
  $content = Get-Content -Raw -Path $postCommit
  if ($content -match 'bohe-session-log') {
    # Strip the marker line and the subsequent bash line referencing our stable hook
    $lines = Get-Content -Path $postCommit
    $kept = @()
    $skipNext = $false
    foreach ($line in $lines) {
      if ($skipNext) { $skipNext = $false; continue }
      if ($line -match '^# bohe-session-log: post-commit draft capture$') {
        $skipNext = $true
        continue
      }
      $kept += $line
    }
    # If only shebang/blank lines remain, remove file entirely
    $meaningful = $kept | Where-Object { $_ -and $_ -notmatch '^\s*$' -and $_ -notmatch '^#!' }
    if (-not $meaningful) {
      Remove-Item -Force $postCommit
      Write-Host "OK  Hook         -> $postCommit (removed — was empty)"
    } else {
      [System.IO.File]::WriteAllText($postCommit, (($kept -join "`n") + "`n"))
      Write-Host "OK  Hook         -> bohe-session-log lines stripped from $postCommit"
    }
  }
}

# ── 3. Stable hook script ──────────────────────────────────────────────────
if (Test-Path $StableDir) {
  Remove-Item -Recurse -Force $StableDir
  Write-Host "OK  Hook script  -> removed $StableDir"
}

Write-Host ''
Write-Host 'Done.'
Write-Host ''
Write-Host 'NOT touched (intentionally):'
Write-Host '  - core.hooksPath setting (your other hooks may rely on it)'
Write-Host '  - docs/session-log/ in your projects (personal records)'
