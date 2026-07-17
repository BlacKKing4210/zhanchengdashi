[CmdletBinding()]
param(
    [string]$SnapshotPath = $env:ZHANCHENG_DASHBOARD_SNAPSHOT_PATH,
    [string]$StateDir = $env:ZHANCHENG_DASHBOARD_STATE_DIR,
    [string]$Host = $(if ($env:ZHANCHENG_DASHBOARD_HOST) { $env:ZHANCHENG_DASHBOARD_HOST } else { "127.0.0.1" }),
    [int]$Port = $(if ($env:ZHANCHENG_DASHBOARD_PORT) { [int]$env:ZHANCHENG_DASHBOARD_PORT } else { 24568 }),
    [string]$TlsKeyPath = $env:ZHANCHENG_DASHBOARD_TLS_KEY_PATH,
    [string]$TlsCertPath = $env:ZHANCHENG_DASHBOARD_TLS_CERT_PATH,
    [switch]$InitializeOwner,
    [string]$OwnerUsername
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js 20 or newer is required to run the admin dashboard."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$dashboardEntry = Join-Path $scriptRoot "admin_dashboard\server.mjs"
if (-not (Test-Path -LiteralPath $dashboardEntry)) {
    throw "Dashboard entry point was not found: $dashboardEntry"
}

if (-not $StateDir) {
    $StateDir = Join-Path $env:LOCALAPPDATA "JungleLaw\AdminDashboard"
}
$env:ZHANCHENG_DASHBOARD_STATE_DIR = [System.IO.Path]::GetFullPath($StateDir)

if ($InitializeOwner) {
    $arguments = @("init-owner", "--state-dir", $env:ZHANCHENG_DASHBOARD_STATE_DIR)
    if ($OwnerUsername) {
        $arguments += @("--username", $OwnerUsername)
    }
    & node $dashboardEntry @arguments
    exit $LASTEXITCODE
}

if (-not $SnapshotPath) {
    throw "Provide -SnapshotPath (must end in dashboard_snapshot.json) or set ZHANCHENG_DASHBOARD_SNAPSHOT_PATH."
}
if ([System.IO.Path]::GetFileName($SnapshotPath).ToLowerInvariant() -ne "dashboard_snapshot.json") {
    throw "SnapshotPath must end in dashboard_snapshot.json. The dashboard will never read player_accounts.json."
}

$isLoopback = $Host -eq "localhost" -or $Host -eq "::1" -or $Host -eq "[::1]" -or $Host -match "^127(\.\d{1,3}){3}$"
if (-not $isLoopback -and ((-not $TlsKeyPath) -or (-not $TlsCertPath))) {
    throw "A non-loopback dashboard host requires both -TlsKeyPath and -TlsCertPath."
}

$env:ZHANCHENG_DASHBOARD_SNAPSHOT_PATH = [System.IO.Path]::GetFullPath($SnapshotPath)
$env:ZHANCHENG_DASHBOARD_HOST = $Host
$env:ZHANCHENG_DASHBOARD_PORT = [string]$Port

if ($TlsKeyPath) {
    $env:ZHANCHENG_DASHBOARD_TLS_KEY_PATH = [System.IO.Path]::GetFullPath($TlsKeyPath)
}
if ($TlsCertPath) {
    $env:ZHANCHENG_DASHBOARD_TLS_CERT_PATH = [System.IO.Path]::GetFullPath($TlsCertPath)
}

& node $dashboardEntry
exit $LASTEXITCODE
