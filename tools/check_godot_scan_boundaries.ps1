[CmdletBinding()]
param(
    [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ProjectRoot = Split-Path -Parent $scriptDirectory
}

$resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$runtimeRoots = @("assets", "runtime", "scenes", "scripts")
$failures = [System.Collections.Generic.List[string]]::new()

foreach ($directory in Get-ChildItem -LiteralPath $resolvedRoot -Directory -Force) {
    if ($directory.Name.StartsWith(".", [System.StringComparison]::Ordinal)) {
        continue
    }
    if ($runtimeRoots -contains $directory.Name) {
        continue
    }
    if (-not (Test-Path -LiteralPath (Join-Path $directory.FullName ".gdignore"))) {
        $failures.Add("Non-runtime root is visible to Godot: $($directory.Name)/")
    }
}

foreach ($runtimeRoot in $runtimeRoots) {
    $runtimePath = Join-Path $resolvedRoot $runtimeRoot
    if (-not (Test-Path -LiteralPath $runtimePath)) {
        $failures.Add("Required runtime root is missing: $runtimeRoot/")
        continue
    }

    $reparsePoints = @(
        Get-ChildItem -LiteralPath $runtimePath -Recurse -Force -Attributes ReparsePoint
    )
    foreach ($reparsePoint in $reparsePoints) {
        $relativePath = [System.IO.Path]::GetRelativePath($resolvedRoot, $reparsePoint.FullName)
        $failures.Add("Runtime scan root contains a junction or symlink: $relativePath")
    }
}

$tempSentinel = Join-Path $resolvedRoot "temp/.gdignore"
if (-not (Test-Path -LiteralPath $tempSentinel)) {
    $failures.Add("Required temporary-directory scan sentinel is missing: temp/.gdignore")
}

$git = Get-Command git -ErrorAction SilentlyContinue
if ($null -ne $git -and (Test-Path -LiteralPath (Join-Path $resolvedRoot ".git"))) {
    Push-Location $resolvedRoot
    try {
        & $git.Source check-ignore --quiet --no-index -- "temp/.gdignore"
        if ($LASTEXITCODE -eq 0) {
            $failures.Add("temp/.gdignore is ignored by Git and cannot protect fresh clones")
        }

        & $git.Source check-ignore --quiet --no-index -- "temp/__godot_scan_boundary_probe__"
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("Temporary contents are not ignored by Git: temp/*")
        }
    }
    finally {
        Pop-Location
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        [Console]::Error.WriteLine("FAIL: $failure")
    }
    exit 1
}

Write-Output "PASS: Godot scans only assets/, runtime/, scenes/, scripts/ and required root files."
Write-Output "PASS: All non-runtime roots have .gdignore boundaries; runtime roots contain no junctions or symlinks."
