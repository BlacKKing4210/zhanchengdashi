[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$GodotExe,
	[string]$PythonExe = 'C:\Users\76398\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',
	[string]$ReleaseDate = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $GodotExe)) {
	throw "Godot console executable was not found: $GodotExe"
}
if (-not (Test-Path -LiteralPath $PythonExe)) {
	throw "Python executable was not found: $PythonExe"
}

function Invoke-ProjectCommand {
	param([string]$Executable, [string[]]$Arguments)
	& $Executable @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "Command failed with exit code ${LASTEXITCODE}: $Executable $($Arguments -join ' ')"
	}
}

function Invoke-GodotExport {
	param([string]$Preset, [string]$OutputPath)
	$parent = Split-Path -Parent $OutputPath
	New-Item -ItemType Directory -Force -Path $parent | Out-Null
	$logPath = Join-Path $projectRoot ("tmp/export_{0}_{1}.log" -f $Preset.Replace(' ', '_').ToLowerInvariant(), $ReleaseDate)
	Invoke-ProjectCommand $GodotExe @(
		'--headless', '--path', $projectRoot,
		'--export-release', $Preset, $OutputPath,
		'--log-file', $logPath
	)
	if (-not (Test-Path -LiteralPath $OutputPath)) {
		throw "Godot reported success but did not produce: $OutputPath"
	}
}

Push-Location $projectRoot
try {
	Invoke-ProjectCommand $PythonExe @('tools/validate_config.py')
	Invoke-ProjectCommand $PythonExe @('tools/export_config.py')

	$windowsDir = Join-Path $projectRoot 'build/windows'
	$androidDir = Join-Path $projectRoot 'build/android'
	$webDir = Join-Path $projectRoot 'build/web'
	$windowsExe = Join-Path $windowsDir 'JungleLaw.exe'
	$windowsDated = Join-Path $windowsDir ("JungleLaw-windows-x64-{0}.zip" -f $ReleaseDate)
	$windowsLatest = Join-Path $windowsDir 'JungleLaw-windows-x64.zip'
	$androidLatest = Join-Path $androidDir 'JungleLaw-android.apk'
	$androidDated = Join-Path $androidDir ("JungleLaw-android-{0}.apk" -f $ReleaseDate)
	$webHtml = Join-Path $webDir 'JungleLaw-web.html'
	$webLatest = Join-Path $webDir 'JungleLaw-web.zip'
	$webDated = Join-Path $webDir ("JungleLaw-web-{0}.zip" -f $ReleaseDate)
	$defaultAndroidKeystore = Join-Path $env:APPDATA 'Godot\keystores\debug.keystore'

	# Keep the default APK installable for internal-device testing. Production
	# pipelines can supply all three GODOT_ANDROID_KEYSTORE_RELEASE_* variables
	# without modifying this project or storing signing material in the repository.
	if ([string]::IsNullOrWhiteSpace($env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH)) {
		if (-not (Test-Path -LiteralPath $defaultAndroidKeystore)) {
			throw "Android debug keystore was not found: $defaultAndroidKeystore"
		}
		$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $defaultAndroidKeystore
		$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = 'androiddebugkey'
		$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = 'android'
	}

	Invoke-GodotExport 'Android' $androidLatest
	Invoke-GodotExport 'Web' $webHtml
	Invoke-GodotExport 'Windows Desktop' $windowsExe

	$windowsTemporary = Join-Path $windowsDir ("JungleLaw-windows-x64-{0}.tmp.zip" -f $ReleaseDate)
	Compress-Archive -LiteralPath $windowsExe -DestinationPath $windowsTemporary -CompressionLevel Optimal -Force
	Move-Item -LiteralPath $windowsTemporary -Destination $windowsDated -Force
	Copy-Item -LiteralPath $windowsDated -Destination $windowsLatest -Force
	$webFiles = Get-ChildItem -LiteralPath $webDir -File | Where-Object {
		$_.Name -like 'JungleLaw-web.*' -and $_.Extension -ne '.zip'
	}
	$requiredWebFiles = @($webHtml, (Join-Path $webDir 'JungleLaw-web.js'), (Join-Path $webDir 'JungleLaw-web.wasm'), (Join-Path $webDir 'JungleLaw-web.pck'))
	$missingWebFiles = $requiredWebFiles | Where-Object { -not (Test-Path -LiteralPath $_) }
	if ($missingWebFiles.Count -gt 0) {
		throw "Web export did not produce required files: $($missingWebFiles -join ', ')"
	}
	$webTemporary = Join-Path $webDir ("JungleLaw-web-{0}.tmp.zip" -f $ReleaseDate)
	Compress-Archive -LiteralPath $webFiles.FullName -DestinationPath $webTemporary -CompressionLevel Optimal -Force
	Move-Item -LiteralPath $webTemporary -Destination $webLatest -Force
	Copy-Item -LiteralPath $androidLatest -Destination $androidDated -Force
	Copy-Item -LiteralPath $webLatest -Destination $webDated -Force

	$artifacts = @($windowsLatest, $windowsDated, $androidLatest, $androidDated, $webLatest, $webDated)
	$artifacts | ForEach-Object {
		$item = Get-Item -LiteralPath $_
		$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_).Hash
		[PSCustomObject]@{
			Path = $item.FullName
			Bytes = $item.Length
			SHA256 = $hash
		}
	} | Format-Table -AutoSize
}
finally {
	Pop-Location
}
