$ErrorActionPreference='Stop'
$taskGeneratedRoot=[IO.Path]::GetFullPath('C:/Users/76398/.codex/generated_images/01a12ae4-aa44-7cf3-99dd-efb71ad75a4e')
$taskPreviewRoot=[IO.Path]::GetFullPath($PSScriptRoot)
if($taskPreviewRoot -ne [IO.Path]::GetFullPath('D:/AI/zhanchengdashi/output/visual_concepts/tata_battle_style/full_game')){throw 'Unexpected preview root'}
$taskPairs=@(
 @('exec-74056326-e8fe-4196-a82c-4cc323c26006.png','gacha_refinement/illustrations/poster.png'),
 @('exec-92071d32-fc4c-4039-af34-58d078c16cf8.png','map_refinement/illustrations/forest-arena.png')
)
$taskBefore=@{};foreach($taskDrive in Get-PSDrive -Name C,D){$taskBefore[$taskDrive.Name]=$taskDrive.Free}
$taskRows=@();$taskRemoved=0L
foreach($taskPair in $taskPairs){
 $taskSource=[IO.Path]::GetFullPath((Join-Path $taskGeneratedRoot $taskPair[0]));$taskRetained=[IO.Path]::GetFullPath((Join-Path $taskPreviewRoot $taskPair[1]))
 if(-not $taskSource.StartsWith($taskGeneratedRoot+'\',[StringComparison]::OrdinalIgnoreCase)-or-not $taskRetained.StartsWith($taskPreviewRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path escapes exact approved scope'}
 foreach($taskCheck in @($taskGeneratedRoot,$taskSource,$taskRetained)){if((Test-Path -LiteralPath $taskCheck)-and((Get-Item -LiteralPath $taskCheck).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Reparse point'}}
 $taskHash=(Get-FileHash -LiteralPath $taskRetained -Algorithm SHA256).Hash;$taskBytes=(Get-Item -LiteralPath $taskRetained).Length
 if(Test-Path -LiteralPath $taskSource){
  if((Get-Item -LiteralPath $taskSource).Length -ne $taskBytes -or(Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash -ne $taskHash){throw 'Duplicate size/hash mismatch; preserve source'}
  $taskHandle=[IO.File]::Open($taskSource,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None);$taskHandle.Dispose();Remove-Item -LiteralPath $taskSource;$taskRemoved+=$taskBytes
 }
 $taskRows+=[pscustomobject]@{source=$taskSource;retained=$taskRetained;sha256=$taskHash;bytes=$taskBytes;result='VERIFIED_RETAINED_SINGLE_FORMAL_ENTITY'}
}
$taskAfter=@{};foreach($taskDrive in Get-PSDrive -Name C,D){$taskAfter[$taskDrive.Name]=$taskDrive.Free}
[ordered]@{request_id='REQ-20261012-GACHA-MAP-REFINEMENT';scope='Exactly two new task-owned builtin image copies; original user/research/source/other-task files excluded';logical_duplicate_deleted_bytes=$taskRemoved;disk_free_before=$taskBefore;disk_free_after=$taskAfter;actual_free_change=@{C=$taskAfter['C']-$taskBefore['C'];D=$taskAfter['D']-$taskBefore['D']};measurement_note='Free-space deltas may include concurrent system activity';relocations=$taskRows}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $taskPreviewRoot 'gacha_refinement/generated-cleanup.json') -Encoding utf8
[pscustomobject]@{duplicates=$taskRows.Count;logical_removed_bytes=$taskRemoved;measured_C_free_change=$taskAfter['C']-$taskBefore['C'];measured_D_free_change=$taskAfter['D']-$taskBefore['D']}
