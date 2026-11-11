<#
.SYNOPSIS
  Put a build of the addons into the WoW Forever AddOns folder, as directory junctions: the addon that holds the
  app's root, what each addon depends on, and what each makes on demand (the build is ../lunatype/zig-out/addons by
  default; `zig build` there writes it). A junction in the AddOns folder that points into this checkout (a build of
  the Lua addons) is taken away and remembered: the two take the same frames of the client's and some share a
  folder's name. -Unlink takes the build's junctions away and puts the remembered ones back. Only junctions are
  ever removed, never files.
#>
[CmdletBinding()]
param(
    [string]$AddOnsPath = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns',
    [string]$Build = (Join-Path $PSScriptRoot '..\..\lunatype\zig-out\addons'),
    [string]$LuaAddons = (Join-Path $PSScriptRoot '..'),
    [switch]$Unlink
)

$ErrorActionPreference = 'Stop'
$build = (Resolve-Path $Build).Path
$remembered = Join-Path $PSScriptRoot 'link.remembered.json'

function Get-Junction($path) {
    $item = Get-Item $path -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq 'Junction') { return $item }
    return $null
}

if ($Unlink) {
    foreach ($addon in Get-ChildItem $build -Directory) {
        $junction = Get-Junction (Join-Path $AddOnsPath $addon.Name)
        if ($junction -and $junction.Target -eq $addon.FullName) {
            $junction.Delete()
            Write-Host "unlinked  $($addon.Name)"
        }
    }
    if (Test-Path $remembered) {
        foreach ($entry in Get-Content $remembered -Raw | ConvertFrom-Json) {
            $link = Join-Path $AddOnsPath $entry.name
            if (Test-Path $link) {
                Write-Warning "$link exists: $($entry.name) isn't put back to $($entry.target)."
                continue
            }
            New-Item -ItemType Junction -Path $link -Target $entry.target | Out-Null
            Write-Host "put back  $($entry.name) -> $($entry.target)"
        }
        Remove-Item $remembered
    }
    return
}

# The Lua Ordaen addons give way, and are remembered for -Unlink.
$lua = (Resolve-Path $LuaAddons -ErrorAction SilentlyContinue).Path
$taken = @()
if (Test-Path $remembered) { $taken = @(Get-Content $remembered -Raw | ConvertFrom-Json) }
if ($lua) {
    foreach ($item in Get-ChildItem $AddOnsPath -Directory -Force) {
        if ($item.LinkType -ne 'Junction') { continue }
        $target = [string]$item.Target
        if ($target.StartsWith($lua, [System.StringComparison]::OrdinalIgnoreCase)) {
            $taken += [pscustomobject]@{ name = $item.Name; target = $target }
            $item.Delete()
            Write-Host "set aside $($item.Name) (was $target)"
        }
    }
}
if ($taken.Count -gt 0) { ConvertTo-Json @($taken) | Set-Content $remembered -Encoding utf8 }

# What the program is made of: the addon that holds its root, what each addon depends on, and what each makes
# something of when it wants to, as the build's TOCs say. An addon of the build that isn't among them is left out.
function Read-Toc($name, $key) {
    $toc = Join-Path $build "$name\$name.toc"
    if (-not (Test-Path $toc)) { return @() }
    foreach ($line in Get-Content $toc) {
        if ($line -match "^## ${key}:\s*(.*)$") { return @($Matches[1] -split '\s*,\s*' | Where-Object { $_ }) }
    }
    return @()
}
$wanted = [System.Collections.Generic.HashSet[string]]::new()
$queue = [System.Collections.Generic.Queue[string]]::new()
foreach ($addon in Get-ChildItem $build -Directory) {
    if ((Read-Toc $addon.Name 'X-LunaType-Root').Count -gt 0) { $queue.Enqueue($addon.Name) }
}
if ($queue.Count -eq 0) { throw "No addon of $build holds the program's root (a class that implements App)." }
while ($queue.Count -gt 0) {
    $name = $queue.Dequeue()
    if (-not $wanted.Add($name)) { continue }
    foreach ($other in (Read-Toc $name 'Dependencies') + (Read-Toc $name 'X-LunaType-Makes')) { $queue.Enqueue($other) }
}

foreach ($addon in Get-ChildItem $build -Directory) {
    if (-not $wanted.Contains($addon.Name)) {
        Write-Host "left out  $($addon.Name)"
        continue
    }
    $link = Join-Path $AddOnsPath $addon.Name
    $existing = Get-Item $link -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.LinkType -eq 'Junction' -and $existing.Target -eq $addon.FullName) {
            Write-Host "ok        $($addon.Name)"
        } else {
            Write-Warning "$link already exists and points elsewhere ($($existing.Target)): it is left as it is."
        }
        continue
    }
    New-Item -ItemType Junction -Path $link -Target $addon.FullName | Out-Null
    Write-Host "linked    $($addon.Name) -> $($addon.FullName)"
}
