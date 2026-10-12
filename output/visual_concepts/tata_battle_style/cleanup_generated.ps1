param([switch]$Execute)
$ErrorActionPreference = 'Stop'
$taskPreviewRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$taskExpectedRoot = [IO.Path]::GetFullPath('D:/AI/zhanchengdashi/output/visual_concepts/tata_battle_style')
if ($taskPreviewRoot -ne $taskExpectedRoot) { throw 'Unexpected task root' }
$taskGeneratedRoots = @(
    'C:/Users/76398/.codex/generated_images/01a12ae4-aa44-7cf3-99dd-efb71ad75a4e',
    'C:/Users/76398/.codex/generated_images/01a12ae8-e0b1-7283-b9eb-711ff560c36b',
    'C:/Users/76398/.codex/generated_images/01a12aeb-6d53-7e52-9d7a-97a490228f51'
)
function Assert-TaskPlainPath([string]$Path, [string]$Root) {
    $taskFull = [IO.Path]::GetFullPath($Path)
    $taskBoundary = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    if ($taskFull -ne $taskBoundary.TrimEnd('\') -and -not $taskFull.StartsWith($taskBoundary, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes boundary: $taskFull" }
    $taskCheck = $taskFull
    while ($taskCheck -and $taskCheck.Length -ge $taskBoundary.TrimEnd('\').Length) {
        if ((Test-Path -LiteralPath $taskCheck) -and ((Get-Item -LiteralPath $taskCheck).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Reparse point: $taskCheck" }
        $taskCheck = [IO.Path]::GetDirectoryName($taskCheck)
    }
}
Assert-TaskPlainPath $taskPreviewRoot $taskExpectedRoot
$taskCanonicalByHash = @{}
foreach ($taskFile in (Get-ChildItem -LiteralPath $taskPreviewRoot -File -Recurse -Filter '*.png')) {
    Assert-TaskPlainPath $taskFile.FullName $taskPreviewRoot
    $taskHash = (Get-FileHash -LiteralPath $taskFile.FullName -Algorithm SHA256).Hash
    if (-not $taskCanonicalByHash.ContainsKey($taskHash)) { $taskCanonicalByHash[$taskHash] = $taskFile.FullName }
}
$taskPlan = @()
foreach ($taskGeneratedRoot in $taskGeneratedRoots) {
    if (-not (Test-Path -LiteralPath $taskGeneratedRoot)) { continue }
    Assert-TaskPlainPath $taskGeneratedRoot $taskGeneratedRoot
    foreach ($taskSource in (Get-ChildItem -LiteralPath $taskGeneratedRoot -File -Filter 'exec-*.png')) {
        Assert-TaskPlainPath $taskSource.FullName $taskGeneratedRoot
        $taskHash = (Get-FileHash -LiteralPath $taskSource.FullName -Algorithm SHA256).Hash
        $taskDuplicate = $taskCanonicalByHash.ContainsKey($taskHash)
        if ($taskDuplicate) { $taskRetained = $taskCanonicalByHash[$taskHash] }
        else {
            $taskRetained = Join-Path $taskPreviewRoot ('iterations/generated_originals/' + [IO.Path]::GetFileName($taskGeneratedRoot) + '/' + $taskSource.Name)
            $taskCanonicalByHash[$taskHash] = $taskRetained
        }
        Assert-TaskPlainPath $taskRetained $taskPreviewRoot
        $taskPlan += [pscustomobject]@{ source=$taskSource.FullName; retained=$taskRetained; sha256=$taskHash; bytes=$taskSource.Length; action=$(if($taskDuplicate){'REMOVE_IDENTICAL_WORKING_COPY'}else{'RELOCATE_UNIQUE_TASK_EVIDENCE'}); result='PLANNED' }
    }
}
$taskFreeBefore = @{}; foreach ($taskDrive in (Get-PSDrive -Name C,D)) { $taskFreeBefore[$taskDrive.Name] = $taskDrive.Free }
$taskRemoved = 0L; $taskDuplicateRemoved = 0L; $taskRelocated = 0L
if ($Execute) {
    foreach ($taskItem in $taskPlan) {
        try {
            if (-not (Test-Path -LiteralPath $taskItem.retained)) {
                if ($taskItem.action -ne 'RELOCATE_UNIQUE_TASK_EVIDENCE') { throw 'Canonical destination absent' }
                $taskParent = [IO.Path]::GetDirectoryName($taskItem.retained)
                Assert-TaskPlainPath $taskParent $taskPreviewRoot
                [IO.Directory]::CreateDirectory($taskParent) | Out-Null
                Copy-Item -LiteralPath $taskItem.source -Destination $taskItem.retained
            }
            Assert-TaskPlainPath $taskItem.retained $taskPreviewRoot
            $taskKeep = Get-Item -LiteralPath $taskItem.retained
            if ($taskKeep.Length -ne $taskItem.bytes -or (Get-FileHash -LiteralPath $taskItem.retained -Algorithm SHA256).Hash -ne $taskItem.sha256) { throw 'Retained size/hash mismatch; source preserved' }
            if ((Get-FileHash -LiteralPath $taskItem.source -Algorithm SHA256).Hash -ne $taskItem.sha256) { throw 'Source changed since inventory' }
            $taskHandle = [IO.File]::Open($taskItem.source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
            $taskHandle.Dispose()
            # Individual, checked literal PNG only; no recursive delete or other shell.
            Remove-Item -LiteralPath $taskItem.source
            if (Test-Path -LiteralPath $taskItem.source) { throw 'Source copy still present' }
            $taskItem.result = 'VERIFIED_AND_SOURCE_COPY_REMOVED'
            $taskRemoved += $taskItem.bytes
            if ($taskItem.action -eq 'REMOVE_IDENTICAL_WORKING_COPY') { $taskDuplicateRemoved += $taskItem.bytes } else { $taskRelocated += $taskItem.bytes }
        } catch {
            $taskItem.result = 'PRESERVED_OR_RETAINED_ON_ERROR: ' + $_.Exception.Message
        }
    }
}
$taskFreeAfter = @{}; foreach ($taskDrive in (Get-PSDrive -Name C,D)) { $taskFreeAfter[$taskDrive.Name] = $taskDrive.Free }
$taskReceipt = [ordered]@{
    request_id='REQ-20261011-TATA-FULL-GAME-PREVIEW'; phase=$(if($Execute){'EXECUTED'}else{'READ_ONLY_PLAN'});
    scope='Only exact three task-owned builtin-generated PNG directories; no user/temp references, source, research cache or other tasks';
    source_png_count=$taskPlan.Count; duplicate_copy_deleted_bytes=$taskDuplicateRemoved; unique_evidence_relocated_bytes=$taskRelocated;
    logical_source_copy_removed_bytes=$taskRemoved; disk_free_before=$taskFreeBefore; disk_free_after=$taskFreeAfter;
    actual_free_change=@{ C=$taskFreeAfter['C']-$taskFreeBefore['C']; D=$taskFreeAfter['D']-$taskFreeBefore['D'] };
    measurement_note='Free-space deltas measured across the operation, may include concurrent system activity; relocated evidence consumes D space.';
    relocations=$taskPlan
}
$taskReceiptFile = Join-Path $taskPreviewRoot $(if($Execute){'cleanup.json'}else{'cleanup-plan.json'})
$taskReceipt | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $taskReceiptFile -Encoding utf8
[pscustomobject]@{phase=$taskReceipt.phase; files=$taskPlan.Count; planned_duplicates=@($taskPlan | Where-Object action -eq 'REMOVE_IDENTICAL_WORKING_COPY').Count; planned_unique=@($taskPlan | Where-Object action -eq 'RELOCATE_UNIQUE_TASK_EVIDENCE').Count; logical_removed_bytes=$taskRemoved; duplicate_deleted_bytes=$taskDuplicateRemoved; unique_relocated_bytes=$taskRelocated; skipped=@($taskPlan | Where-Object result -like 'PRESERVED*').Count}
