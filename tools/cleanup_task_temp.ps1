[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][string]$PlanPath,
    [switch]$Apply
)

# Only disposable QA directories in this repository. The caller owns authorization.
$ErrorActionPreference = 'Stop'
foreach ($requestedPath in @($TargetPath, $PlanPath)) {
    if (-not [IO.Path]::IsPathFullyQualified($requestedPath) -or (($requestedPath -split '[\\/]') -contains '..')) {
        throw 'Use an absolute path without parent traversal segments.'
    }
}
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$boundary = [IO.Path]::GetFullPath((Join-Path $projectRoot 'temp/qa')).TrimEnd('\', '/')
$target = [IO.Path]::GetFullPath($TargetPath).TrimEnd('\', '/')
$planFile = [IO.Path]::GetFullPath($PlanPath)
$separator = [IO.Path]::DirectorySeparatorChar
function Is-Within([string]$Child, [string]$Parent) {
    return $Child.StartsWith($Parent + $separator, [StringComparison]::OrdinalIgnoreCase)
}
function Assert-RegularPath([string]$Path) {
    $cursor = $Path
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point rejected: $cursor" }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
if (-not (Is-Within $target $boundary)) { throw 'Target must be a strict child of this project temp/qa directory.' }
if (-not (Is-Within $planFile $boundary) -or (Is-Within $planFile $target) -or $planFile -eq $target) {
    throw 'Plan must stay inside temp/qa and outside the removal target.'
}
Assert-RegularPath $target
Assert-RegularPath $planFile
if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw 'Target directory does not exist.' }

function Read-Snapshot {
    $files = @()
    $directories = @()
    $pending = [Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($target)
    while ($pending.Count -gt 0) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Dequeue() -Force) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point rejected: $($item.FullName)" }
            $relative = $item.FullName.Substring($target.Length + 1)
            if ($item.PSIsContainer) { $directories += $relative; $pending.Enqueue($item.FullName) }
            else {
                $files += [ordered]@{ path = $relative; bytes = $item.Length; sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash }
            }
        }
    }
    return [ordered]@{ target = $target; files = @($files | Sort-Object { $_.path }); directories = @($directories | Sort-Object) }
}
$snapshot = Read-Snapshot
$canonical = $snapshot | ConvertTo-Json -Depth 8 -Compress
if (-not $Apply) {
    if (Test-Path -LiteralPath $planFile) { throw 'Plan already exists; review it instead of overwriting it.' }
    New-Item -ItemType Directory -Path (Split-Path -Parent $planFile) -Force | Out-Null
    [IO.File]::WriteAllText($planFile, ($snapshot | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $plannedBytes = ($snapshot.files | ForEach-Object { $_.bytes } | Measure-Object -Sum).Sum
    Write-Output "PLAN_ONLY files=$($snapshot.files.Count) bytes=$plannedBytes plan=$planFile"
    return
}
if (-not (Test-Path -LiteralPath $planFile -PathType Leaf)) { throw 'Apply requires the existing reviewed plan.' }
$approved = Get-Content -LiteralPath $planFile -Raw -Encoding UTF8 | ConvertFrom-Json
$approvedCanonical = $approved | ConvertTo-Json -Depth 8 -Compress
if ($canonical -cne $approvedCanonical) { throw 'Target content differs from the reviewed plan; nothing deleted.' }
$receiptFile = $planFile + '.result.json'
if (Test-Path -LiteralPath $receiptFile) { throw 'A result receipt already exists; refusing to overwrite it.' }
$drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($target))
$freeBefore = $drive.AvailableFreeSpace
$removedBytes = 0L
$removedFiles = 0
$outcome = 'PARTIAL'
$failure = $null
try {
    # Hash-check the complete set first; then remove only named files, never recursively.
    foreach ($entry in $snapshot.files) {
        $file = Join-Path $target $entry.path
        Assert-RegularPath $file
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -cne $entry.sha256) { throw "File changed: $($entry.path)" }
        Remove-Item -LiteralPath $file -Force -ErrorAction Stop
        $removedBytes += $entry.bytes
        $removedFiles++
    }
    foreach ($relative in ($snapshot.directories | Sort-Object Length -Descending)) {
        $directory = Join-Path $target $relative
        Assert-RegularPath $directory
        if (@(Get-ChildItem -LiteralPath $directory -Force).Count -ne 0) { throw "Directory gained content: $relative" }
        Remove-Item -LiteralPath $directory -ErrorAction Stop
    }
    if (@(Get-ChildItem -LiteralPath $target -Force).Count -ne 0) { throw 'Target gained content; preserving it.' }
    Remove-Item -LiteralPath $target -ErrorAction Stop
    if (Test-Path -LiteralPath $target) { throw 'Target still exists after cleanup.' }
    $outcome = 'REMOVED_VERIFIED'
} catch { $failure = $_.Exception.Message }
[ordered]@{
    target = $target; status = $outcome; files_deleted = $removedFiles; logical_bytes_deleted = $removedBytes
    volume_free_space_delta_bytes = $drive.AvailableFreeSpace - $freeBefore
    free_space_note = 'Observed volume delta may include unrelated concurrent I/O; logical removed bytes are exact.'
    absent = -not (Test-Path -LiteralPath $target); error = $failure
} | ConvertTo-Json | Set-Content -LiteralPath $receiptFile -Encoding UTF8
if ($failure) { throw $failure }
Write-Output "REMOVED_VERIFIED files=$removedFiles bytes=$removedBytes receipt=$receiptFile"
