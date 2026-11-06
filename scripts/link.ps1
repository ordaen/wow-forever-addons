<#
.SYNOPSIS
  Link every addon in addons/ (and addons nested one level down) into the WoW Forever AddOns
  folder using directory junctions.

.DESCRIPTION
  A junction is Windows' directory link (like a Linux symlink to a directory). Unlike real
  symlinks it needs no admin rights or Developer Mode. WoW follows it, so edits in the repo
  show up in game after /reload. Changes to a .toc file or new files need a full client restart.

  Deleting a junction (Remove-Item, or -Unlink here) removes only the link, never the repo files.

.EXAMPLE
  ./scripts/link.ps1
  ./scripts/link.ps1 -Unlink
  ./scripts/link.ps1 -AddOnsPath 'D:\Games\World of Warcraft\_forever_\Interface\AddOns'
#>
[CmdletBinding()]
param(
    [string]$AddOnsPath = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns',
    [switch]$Unlink
)

$ErrorActionPreference = 'Stop'
$addonsRoot = Join-Path $PSScriptRoot '..\addons' | Resolve-Path

if (-not (Test-Path $AddOnsPath)) {
    throw "AddOns folder not found: $AddOnsPath (pass -AddOnsPath)"
}

# Top-level addon folders, plus addons nested one level down that ship in the same package
# (e.g. addons/OrdaenCore/OrdaenCore_Debug): any subfolder with a <FolderName>.toc.
$addons = @(Get-ChildItem $addonsRoot -Directory)
$addons += @($addons | ForEach-Object { Get-ChildItem $_.FullName -Directory } |
    Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).toc") })

foreach ($addon in $addons) {
    $link = Join-Path $AddOnsPath $addon.Name
    $existing = Get-Item $link -Force -ErrorAction SilentlyContinue

    if ($Unlink) {
        if ($existing -and $existing.LinkType -eq 'Junction') {
            $existing.Delete()  # removes the link only
            Write-Host "unlinked  $($addon.Name)"
        }
        continue
    }

    if ($existing) {
        if ($existing.LinkType -eq 'Junction' -and $existing.Target -eq $addon.FullName) {
            Write-Host "ok        $($addon.Name)"
        } else {
            Write-Warning "$link already exists and is not a junction to this repo (an installed copy?). Remove or rename it, then rerun."
        }
        continue
    }

    New-Item -ItemType Junction -Path $link -Target $addon.FullName | Out-Null
    Write-Host "linked    $($addon.Name) -> $($addon.FullName)"
}
