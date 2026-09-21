<#
.SYNOPSIS
    Copy this addon into a WoW AddOns folder for testing.

.DESCRIPTION
    Development helper. The repo is the source of truth; this pushes it into the
    live AddOns directory so the change can be tested with /reload.

    A directory junction would avoid the copy, but junctions are avoided here
    deliberately: one was used earlier while chasing a SavedVariables bug and had
    to be ruled out as a cause, which cost time. A plain copy has no such doubt.

    The AddOns path is resolved in this order:
      1. -AddonsPath argument
      2. $env:WOW_ADDONS
      3. auto-detection of a WoW install on this machine

.EXAMPLE
    pwsh -File sync.ps1
    pwsh -File sync.ps1 -AddonsPath "D:\WoW\_retail_\Interface\AddOns"
    $env:WOW_ADDONS = "D:\WoW\_classic_era_\Interface\AddOns"; pwsh -File sync.ps1
#>
[CmdletBinding()]
param(
    [string]$AddonsPath,
    # Must match the .toc filename, which is why it carries the -main suffix:
    # a GitHub "Download ZIP" of the main branch unpacks to <repo>-main.
    [string]$FolderName = 'wowEmoteMenu-main'
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot

function Resolve-AddonsPath {
    if ($AddonsPath) { return $AddonsPath }
    if ($env:WOW_ADDONS) { return $env:WOW_ADDONS }

    $roots = @(
        "C:\Program Files (x86)\World of Warcraft",
        "C:\Program Files\World of Warcraft",
        "D:\World of Warcraft",
        "$env:ProgramFiles\World of Warcraft"
    ) | Where-Object { Test-Path $_ } | Select-Object -Unique

    foreach ($root in $roots) {
        # Prefer whichever flavour was played most recently.
        $flavours = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '_*_' } |
            Sort-Object LastWriteTime -Descending
        foreach ($f in $flavours) {
            $candidate = Join-Path $f.FullName 'Interface\AddOns'
            if (Test-Path $candidate) { return $candidate }
        }
    }
    throw "Could not find a WoW AddOns folder. Pass -AddonsPath or set `$env:WOW_ADDONS."
}

$addons = Resolve-AddonsPath
if (-not (Test-Path $addons)) { throw "AddOns path does not exist: $addons" }
$live = Join-Path $addons $FolderName

# Repo plumbing that must never reach the AddOns folder.
$exclude = @('.git', '.github', '.claude', '.gitignore', '.gitattributes', 'sync.ps1', 'tests')

if (Test-Path $live) {
    $item = Get-Item $live -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        [IO.Directory]::Delete($live, $false)   # remove the link, not the target
        Write-Host "Removed existing junction."
    } else {
        Remove-Item $live -Recurse -Force
    }
}
New-Item -ItemType Directory -Path $live | Out-Null

$copied = 0
Get-ChildItem $repo -Recurse -File -Force | ForEach-Object {
    $rel = $_.FullName.Substring($repo.Length + 1)
    if ($exclude -contains $rel.Split([IO.Path]::DirectorySeparatorChar)[0]) { return }
    $dest = Join-Path $live $rel
    $dir = Split-Path $dest -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Copy-Item $_.FullName $dest -Force
    $copied++
}

Write-Host "Synced $copied file(s) to:"
Write-Host "  $live"

# Every file the .toc lists must actually be there, or the addon fails silently.
$toc = Join-Path $live "$FolderName.toc"
if (-not (Test-Path $toc)) { throw "No .toc at $toc -- is -FolderName correct?" }

$missing = Get-Content $toc | ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') } |
    Where-Object { -not (Test-Path (Join-Path $live $_)) }

if ($missing) {
    Write-Host "MISSING files listed in the .toc:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  $_" }
    exit 1
}
Write-Host "All .toc-listed files present."
