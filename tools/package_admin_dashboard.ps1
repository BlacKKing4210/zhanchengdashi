[CmdletBinding()]
param(
    [string]$ReleaseVersion = "",
    [string]$CandidateLabel = "local",
    [string]$OutputDirectory = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$packagePath = Join-Path $projectRoot "tools\admin_dashboard\package.json"
$package = Get-Content -Raw -Encoding UTF8 -LiteralPath $packagePath | ConvertFrom-Json

if (-not $ReleaseVersion) {
    $ReleaseVersion = [string]$package.version
}
if ($ReleaseVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "ReleaseVersion must use semantic version form x.y.z."
}
if ([string]$package.version -ne $ReleaseVersion) {
    throw "package.json version '$($package.version)' does not match requested release '$ReleaseVersion'."
}
if ($CandidateLabel -notmatch '^[a-z0-9][a-z0-9.-]*$') {
    throw "CandidateLabel may contain only lowercase letters, numbers, dots, and hyphens."
}

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $projectRoot "build\admin-dashboard"
}
$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null

$artifactBase = "JungleLaw-admin-dashboard-v$ReleaseVersion-$CandidateLabel"
$archivePath = Join-Path $outputRoot "$artifactBase.zip"
$manifestPath = Join-Path $outputRoot "$artifactBase.manifest.json"
if ((Test-Path -LiteralPath $archivePath) -or (Test-Path -LiteralPath $manifestPath)) {
    throw "Refusing to overwrite an existing candidate artifact or manifest in '$outputRoot'."
}

# This allow-list is the complete release boundary. Do not replace it with a
# recursive directory glob: tests, state, snapshots, commands, credentials,
# profiles, and node_modules are deliberately outside the candidate release.
$releaseFiles = @(
    "tools/admin_dashboard/package.json",
    "tools/admin_dashboard/server.mjs",
    "tools/admin_dashboard/lib/account_snapshot.mjs",
    "tools/admin_dashboard/lib/auth.mjs",
    "tools/admin_dashboard/lib/http_utils.mjs",
    "tools/admin_dashboard/lib/resource_grants.mjs",
    "tools/admin_dashboard/lib/snapshot.mjs",
    "tools/admin_dashboard/lib/state_store.mjs",
    "tools/admin_dashboard/public/app.js",
    "tools/admin_dashboard/public/index.html",
    "tools/admin_dashboard/public/styles.css",
    "deploy/linux/ADMIN_DASHBOARD_DEPLOYMENT.md",
    "deploy/linux/admin_dashboard_preflight.sh",
    "deploy/linux/junglelaw-admin-dashboard.env.example",
    "deploy/linux/junglelaw-admin-dashboard.service.example",
    "deploy/linux/junglelaw-admin-dashboard-public-443.conf.example",
    "deploy/linux/install_junglelaw_admin_dashboard.sh",
    "deploy/linux/junglelaw-admin-dashboard-cert-renew",
    "deploy/linux/junglelaw-admin-dashboard-cert-renew.service.example",
    "deploy/linux/junglelaw-admin-dashboard-cert-renew.timer.example",
    "deploy/linux/junglelaw-server-admin-dashboard.conf.example"
)

$sourceEntries = foreach ($relativePath in $releaseFiles) {
    if ($relativePath.Contains("..") -or [System.IO.Path]::IsPathRooted($relativePath)) {
        throw "Unsafe release path '$relativePath'."
    }
    $sourcePath = Join-Path $projectRoot ($relativePath -replace '/', '\')
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required release file is missing: $relativePath"
    }
    $item = Get-Item -LiteralPath $sourcePath
    [pscustomobject]@{
        path = $relativePath
        source_path = $sourcePath
        size_bytes = [int64]$item.Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash.ToLowerInvariant()
    }
}

Add-Type -AssemblyName System.IO.Compression
$archiveStream = [System.IO.File]::Open(
    $archivePath,
    [System.IO.FileMode]::CreateNew,
    [System.IO.FileAccess]::ReadWrite,
    [System.IO.FileShare]::None
)
try {
    $archive = [System.IO.Compression.ZipArchive]::new(
        $archiveStream,
        [System.IO.Compression.ZipArchiveMode]::Create,
        $false
    )
    try {
        $fixedTimestamp = [System.DateTimeOffset]::Parse("2000-01-01T00:00:00Z")
        foreach ($sourceEntry in $sourceEntries) {
            $entry = $archive.CreateEntry(
                [string]$sourceEntry.path,
                [System.IO.Compression.CompressionLevel]::Optimal
            )
            $entry.LastWriteTime = $fixedTimestamp
            $input = [System.IO.File]::OpenRead([string]$sourceEntry.source_path)
            $output = $entry.Open()
            try {
                $input.CopyTo($output)
            }
            finally {
                $output.Dispose()
                $input.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}
catch {
    $archiveStream.Dispose()
    Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
    throw
}
finally {
    if ($archiveStream) {
        $archiveStream.Dispose()
    }
}

$gitHead = (& git -C $projectRoot rev-parse HEAD 2>$null).Trim()
$gitBranch = (& git -C $projectRoot branch --show-current 2>$null).Trim()
$gitStatus = @(& git -C $projectRoot status --porcelain=v1 --untracked-files=all 2>$null)
$scopedDirty = @()
foreach ($line in $gitStatus) {
    if ($line.Length -lt 4) {
        continue
    }
    $changedPath = $line.Substring(3).Replace('\', '/')
    if ($releaseFiles -contains $changedPath) {
        $scopedDirty += $changedPath
    }
}

$archiveItem = Get-Item -LiteralPath $archivePath
$manifest = [ordered]@{
    schema_version = 1
    artifact = [ordered]@{
        name = $artifactBase
        version = $ReleaseVersion
        status = "local_release_candidate_not_deployed"
        file = $archiveItem.Name
        size_bytes = [int64]$archiveItem.Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
    }
    provenance = [ordered]@{
        project = "zhanchengdashi"
        git_branch = $gitBranch
        git_head = $gitHead
        source_tree_state = if ($gitStatus.Count -gt 0) { "dirty" } else { "clean" }
        candidate_source_dirty_paths = @($scopedDirty | Sort-Object -Unique)
        unrelated_dirty_paths_present = [bool]($gitStatus.Count -gt $scopedDirty.Count)
        package_script = "tools/package_admin_dashboard.ps1"
        built_at_utc = [System.DateTimeOffset]::UtcNow.ToString("o")
    }
    runtime = [ordered]@{
        node = [string]$package.engines.node
        third_party_dependencies = @()
        npm_install_required = $false
        test_files_included = $false
        remote_release_check = "node --check tools/admin_dashboard/server.mjs"
    }
    entries = @($sourceEntries | ForEach-Object {
        [ordered]@{
            path = $_.path
            size_bytes = $_.size_bytes
            sha256 = $_.sha256
        }
    })
    exclusions = @(
        "tests/**",
        "README.md",
        "state/account/command data",
        "production/deployment/aliyun-profile.yaml",
        "credentials and TLS key material",
        "node_modules/**"
    )
}

$manifestJson = $manifest | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText(
    $manifestPath,
    $manifestJson + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

[pscustomobject]@{
    archive = $archivePath
    manifest = $manifestPath
    sha256 = $manifest.artifact.sha256
    entries = $sourceEntries.Count
    status = $manifest.artifact.status
}
