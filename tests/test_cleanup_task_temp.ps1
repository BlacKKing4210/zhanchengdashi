[CmdletBinding()]
param([string]$Stage = 'baseline')

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$tool = Join-Path $project 'tools/cleanup_task_temp.ps1'
$qa = Join-Path $project 'temp/qa/cleanup-apk-20260925'
$shell = (Get-Process -Id $PID).Path
$checks = [Collections.Generic.List[object]]::new()
$scriptHashBefore = (Get-FileHash -LiteralPath $tool -Algorithm SHA256).Hash

function Get-FixtureResidue([string]$NamePrefix = 'fixture-') {
    $roots = @()
    if (Test-Path -LiteralPath $qa -PathType Container) {
        $roots = @(Get-ChildItem -LiteralPath $qa -Directory -Force | Where-Object { $_.Name.StartsWith($NamePrefix, [StringComparison]::Ordinal) } | Sort-Object FullName)
    }
    $directories = [Collections.Generic.List[string]]::new()
    $files = [Collections.Generic.List[object]]::new()
    $links = [Collections.Generic.List[object]]::new()
    $pending = [Collections.Generic.Queue[object]]::new()
    foreach ($item in $roots) { $pending.Enqueue($item) }
    while ($pending.Count -gt 0) {
        $item = $pending.Dequeue()
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $links.Add([ordered]@{ path = $item.FullName; target = $item.LinkTarget })
        } elseif ($item.PSIsContainer) {
            $directories.Add($item.FullName)
            foreach ($child in @(Get-ChildItem -LiteralPath $item.FullName -Force | Sort-Object FullName)) { $pending.Enqueue($child) }
        } else {
            $files.Add([ordered]@{ path = $item.FullName; bytes = $item.Length })
        }
    }
    return [pscustomobject]@{
        status = $(if ($roots.Count) { 'CLEANUP_REQUIRED' } else { 'CLEAN' })
        fixture_roots = @($roots | ForEach-Object { $_.FullName })
        directories = $directories; files = $files; reparse_points = $links
        logical_bytes_retained = ($files | ForEach-Object { $_.bytes } | Measure-Object -Sum).Sum
    }
}

# Refuse a new run before creating any fixtures when an earlier run still needs cleanup.
$existingResidue = Get-FixtureResidue
if ($existingResidue.fixture_roots.Count -gt 0) {
    $guardReport = [ordered]@{
        stage = $Stage; status = 'CLEANUP_REQUIRED'
        functional_checks = [ordered]@{ status = 'NOT_RUN'; count = 0; failures = 0 }
        cleanup_state = $existingResidue
        tool_sha256 = $scriptHashBefore
        probe_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
        boundary = 'No fixtures were created or deleted. Existing reparse points were inventoried without traversal.'
    }
    $guardReport | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $qa "review-guard-$Stage.json") -Encoding UTF8
    Write-Host "CLEANUP_REQUIRED existing_fixture_directories=$($existingResidue.fixture_roots.Count) functional_checks=NOT_RUN"
    exit 2
}

$run = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$prefix = "fixture-$run"
New-Item -ItemType Directory -Path $qa -Force | Out-Null

function Check([bool]$Ok, [string]$Name, $Actual = $null) {
    $checks.Add([ordered]@{ id = $Name; pass = $Ok; actual = $Actual })
    if (-not $Ok) { Write-Host "CLEANUP_TEST_FAIL $Name actual=$Actual" }
}

function Fixture([string]$Name) {
    $path = Join-Path $qa "$prefix-$Name"
    if (Test-Path -LiteralPath $path) { throw 'Fixture collision' }
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function Put([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Plan-Path([string]$Name) { return Join-Path $qa "$prefix-$Name.plan.json" }

function Invoke-Cleanup([string]$Target, [string]$Plan, [switch]$Apply) {
    $arguments = @('-NoProfile', '-File', $tool, '-TargetPath', $Target, '-PlanPath', $Plan)
    if ($Apply) { $arguments += '-Apply' }
    $output = @(& $shell @arguments 2>&1)
    $code = $LASTEXITCODE
    return [pscustomobject]@{ code = $code; output = ($output -join "`n") }
}

# Positive control: plan is read-only, while apply removes only the reviewed set.
$safe = Fixture 'safe'
New-Item -ItemType Directory -Path (Join-Path $safe 'nested') | Out-Null
$first = Join-Path $safe 'a.txt'
$second = Join-Path $safe 'nested/b.txt'
Put $first 'alpha'
Put $second 'beta123'
$expectedBytes = (Get-Item -LiteralPath $first).Length + (Get-Item -LiteralPath $second).Length
$plan = Plan-Path 'safe'
$result = Invoke-Cleanup $safe $plan
Check ($result.code -eq 0) 'safe_plan_succeeds' $result.output
Check ((Test-Path -LiteralPath $first) -and (Test-Path -LiteralPath $second)) 'plan_alone_keeps_every_file'
$snapshot = Get-Content -LiteralPath $plan -Raw | ConvertFrom-Json
Check ($snapshot.files.Count -eq 2 -and $snapshot.directories.Count -eq 1) 'plan_records_full_file_and_directory_set'
Check ($result.output.Contains("bytes=$expectedBytes ")) 'plan_prints_exact_logical_bytes' $result.output
$result = Invoke-Cleanup $safe $plan -Apply
Check ($result.code -eq 0 -and -not (Test-Path -LiteralPath $safe)) 'safe_apply_removes_target' $result.output
$receipt = Get-Content -LiteralPath ($plan + '.result.json') -Raw | ConvertFrom-Json
Check ($receipt.status -eq 'REMOVED_VERIFIED' -and $receipt.files_deleted -eq 2 -and $receipt.logical_bytes_deleted -eq $expectedBytes) 'receipt_records_exact_removed_files_and_logical_bytes' $receipt
Check ($null -ne $receipt.volume_free_space_delta_bytes -and $receipt.free_space_note.Contains('concurrent')) 'receipt_separates_measured_volume_change'

# Refusal cases only use PLAN on real shared roots, never a mutating request.
$guard = Fixture 'guard'
$guardFile = Join-Path $guard 'keep.txt'
Put $guardFile 'keep'
$qaRoot = Join-Path $project 'temp/qa'
$targets = [ordered]@{
    'outside_project' = [IO.Path]::GetDirectoryName($project)
    'filesystem_root' = [IO.Path]::GetPathRoot($project)
    'project_root' = $project
    'equal_qa_root' = $qaRoot
    'target_is_file' = $guardFile
    'relative_target' = [IO.Path]::GetRelativePath($project, $guard)
    'traversal_target' = (Join-Path $guard ('../' + [IO.Path]::GetFileName($guard)))
}
foreach ($entry in $targets.GetEnumerator()) {
    $result = Invoke-Cleanup $entry.Value (Plan-Path $entry.Key)
    Check ($result.code -ne 0) ('reject_' + $entry.Key) $result.output
}
Check ((Get-Content -LiteralPath $guardFile -Raw) -eq 'keep') 'guard_fixture_unchanged_after_path_refusals'
$result = Invoke-Cleanup $guard (Join-Path $guard 'plan.json')
Check ($result.code -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $guard 'plan.json'))) 'reject_plan_inside_target'
$result = Invoke-Cleanup $guard (Join-Path $project "$prefix-not-created.json")
Check ($result.code -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $project "$prefix-not-created.json"))) 'reject_plan_outside_qa'
$relativePlan = [IO.Path]::GetRelativePath($project, (Plan-Path 'relative-plan'))
$result = Invoke-Cleanup $guard $relativePlan
Check ($result.code -ne 0) 'reject_relative_plan' $result.output
$traversalPlan = Join-Path $qa ('../cleanup-apk-20260925/' + $prefix + '-traversal-plan.json')
$result = Invoke-Cleanup $guard $traversalPlan
Check ($result.code -ne 0) 'reject_traversal_plan' $result.output

foreach ($change in @('changed', 'newfile', 'newdirectory', 'tampered-plan')) {
    $target = Fixture $change
    $a = Join-Path $target 'a.txt'
    $b = Join-Path $target 'b.txt'
    Put $a 'first'
    Put $b 'second'
    $plan = Plan-Path $change
    $result = Invoke-Cleanup $target $plan
    Check ($result.code -eq 0) ($change + '_baseline_plan_created')
    switch ($change) {
        'changed' { Put $b 'change' } # Same length; only its hash detects this edit.
        'newfile' { Put (Join-Path $target 'new.txt') 'new' }
        'newdirectory' { New-Item -ItemType Directory -Path (Join-Path $target 'new-directory') | Out-Null }
        'tampered-plan' {
            $altered = Get-Content -LiteralPath $plan -Raw | ConvertFrom-Json
            $altered.files[0].path = '../../not-a-fixture.txt'
            $altered | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $plan
        }
    }
    $result = Invoke-Cleanup $target $plan -Apply
    Check ($result.code -ne 0) ($change + '_apply_refused') $result.output
    Check ((Test-Path -LiteralPath $a) -and (Test-Path -LiteralPath $b) -and (Get-Content -LiteralPath $a -Raw) -eq 'first') ($change + '_refusal_precedes_any_deletion')
    Check (-not (Test-Path -LiteralPath ($plan + '.result.json'))) ($change + '_no_success_receipt_written')
}

$existingPlan = Plan-Path 'existing'
$result = Invoke-Cleanup $guard $existingPlan
$oldHash = (Get-FileHash -LiteralPath $existingPlan).Hash
$result = Invoke-Cleanup $guard $existingPlan
Check ($result.code -ne 0 -and (Get-FileHash -LiteralPath $existingPlan).Hash -eq $oldHash) 'existing_plan_is_not_overwritten'

# Owned local junction fixtures prove both child and ancestor reparse checks.
$linked = Fixture 'linked-data'
$linkedFile = Join-Path $linked 'keep.txt'
Put $linkedFile 'linked data stays intact'
$linkHolder = Fixture 'link-holder'
$link = Join-Path $linkHolder 'junction'
$junctionCreated = $false
try {
    New-Item -ItemType Junction -Path $link -Target $linked | Out-Null
    $junctionCreated = $true
} catch {
    $checks.Add([ordered]@{ id = 'junction_setup'; pass = $null; skip = $_.Exception.Message })
}
if ($junctionCreated) {
    $result = Invoke-Cleanup $linkHolder (Plan-Path 'child-link')
    Check ($result.code -ne 0) 'reject_child_junction' $result.output
    $result = Invoke-Cleanup $link (Plan-Path 'root-link')
    Check ($result.code -ne 0) 'reject_target_junction' $result.output
    $result = Invoke-Cleanup $guard (Join-Path $link 'plan.json')
    Check ($result.code -ne 0) 'reject_plan_parent_junction' $result.output
    Check ((Get-Content -LiteralPath $linkedFile -Raw) -eq 'linked data stays intact') 'junction_target_data_is_untouched'
}

# An OS-locked second file can cause a partial deletion; receipt must say so.
$partial = Fixture 'partial'
$a = Join-Path $partial 'a.txt'
$b = Join-Path $partial 'b.txt'
Put $a 'first'
Put $b 'locked'
$plan = Plan-Path 'partial'
$result = Invoke-Cleanup $partial $plan
$lock = [IO.File]::Open($b, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try { $result = Invoke-Cleanup $partial $plan -Apply } finally { $lock.Dispose() }
Check ($result.code -ne 0) 'locked_file_returns_failure' $result.output
$receipt = Get-Content -LiteralPath ($plan + '.result.json') -Raw | ConvertFrom-Json
Check ($receipt.status -eq 'PARTIAL' -and $receipt.files_deleted -eq 1 -and $receipt.logical_bytes_deleted -eq 5 -and -not $receipt.absent) 'partial_receipt_reports_only_actual_deletions' $receipt
Check (-not (Test-Path -LiteralPath $a) -and (Test-Path -LiteralPath $b)) 'partial_failure_preserves_locked_file'

$scriptHashAfter = (Get-FileHash -LiteralPath $tool -Algorithm SHA256).Hash
Check ($scriptHashBefore -eq $scriptHashAfter) 'implementation_did_not_change_during_run'
$failed = @($checks | Where-Object { $_.pass -ceq $false }).Count
$residue = Get-FixtureResidue ($prefix + '-')
$report = [ordered]@{
    stage = $Stage; checks = $checks; failures = $failed; fixture_prefix = $prefix
    status = $(if ($residue.fixture_roots.Count) { 'CLEANUP_REQUIRED' } elseif ($failed) { 'FAIL' } else { 'PASS' })
    functional_checks = [ordered]@{ status = $(if ($failed) { 'FAIL' } else { 'PASS' }); count = $checks.Count; failures = $failed }
    cleanup_state = $residue
    tool_sha256 = $scriptHashAfter; probe_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
    powershell = $PSVersionTable.PSVersion.ToString(); boundary = 'Only owned fixture files were deleted. Real shared paths were tested with plan-only refusals.'
}
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $qa "review-report-$Stage.json") -Encoding UTF8
Write-Host "CLEANUP_FUNCTIONAL_TEST checks=$($checks.Count) failures=$failed cleanup_state=$($residue.status)"
if ($residue.fixture_roots.Count) {
    Write-Host "CLEANUP_REQUIRED fixture_prefix=$prefix retained_directories=$($residue.fixture_roots.Count)"
    exit 2
}
if ($failed) { exit 1 }
