$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath($PSScriptRoot)
$taskAllowed=[IO.Path]::GetFullPath('D:/AI/zhanchengdashi/output/visual_concepts/tata_battle_style/full_game')
if($taskRoot -ne $taskAllowed){throw 'Unexpected preview task root'}
function Assert-TaskPreviewPath([string]$Path){
 $taskFull=[IO.Path]::GetFullPath($Path)
 if(-not $taskFull.StartsWith($taskRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path escapes preview delivery'}
 $taskCheck=$taskFull
 while($taskCheck.Length -ge $taskRoot.Length){if((Test-Path -LiteralPath $taskCheck)-and((Get-Item -LiteralPath $taskCheck).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Reparse point'};$taskCheck=[IO.Path]::GetDirectoryName($taskCheck)}
}
$taskBaseline=Get-Content -LiteralPath (Join-Path $taskRoot 'gacha_refinement/preflight.json') -Raw | ConvertFrom-Json
$taskOldHashes=@{};foreach($taskOriginal in $taskBaseline.protected_existing_views){$taskOldHashes[$taskOriginal.file]=$taskOriginal.sha256}
$taskJobs=@()
foreach($taskReviewName in @('gacha','maps')){
 $taskReviewPath=Join-Path $taskRoot ('reviews/refinement-20261012/'+$taskReviewName+'.json')
 $taskReview=Get-Content -LiteralPath $taskReviewPath -Raw | ConvertFrom-Json
 if($taskReview.status -ne 'BATCH_STATIC_PREVIEW_PASS'){throw ('Review not complete: '+$taskReviewName)}
 foreach($taskReviewed in $taskReview.files){
  if($taskReviewed.verdict -ne 'PREVIEW_PASS' -or $taskReviewed.p0.Count -or $taskReviewed.p1.Count){throw 'Open image review issue'}
  $taskSource=Join-Path $taskRoot $taskReviewed.candidate_path;$taskTarget=Join-Path $taskRoot $taskReviewed.path
  Assert-TaskPreviewPath $taskSource;Assert-TaskPreviewPath $taskTarget
  if($taskReviewed.path -notmatch '^(core_pages|root_pages)/[0-9]{2}_[a-z_]+\.png$'){throw 'Unexpected canonical PNG path'}
  $taskJobs += [pscustomobject]@{source=$taskSource;target=$taskTarget;path=$taskReviewed.path;expected=$taskReviewed.sha256;old=$taskOldHashes[$taskReviewed.path];kind=$taskReviewName;archive=$null}
 }
}
if($taskJobs.Count -ne 10){throw 'Expected5gacha and5map reviewed PNG'}
# Verify all images and old targets before any move.
foreach($taskJob in $taskJobs){
 if(-not(Test-Path -LiteralPath $taskJob.source)){if((Test-Path -LiteralPath $taskJob.target)-and((Get-FileHash -LiteralPath $taskJob.target -Algorithm SHA256).Hash -eq $taskJob.expected)){continue};throw 'Missing reviewed candidate'}
 if((Get-FileHash -LiteralPath $taskJob.source -Algorithm SHA256).Hash -ne $taskJob.expected){throw 'Reviewed candidate SHA changed'}
 if(Test-Path -LiteralPath $taskJob.target){if((Get-FileHash -LiteralPath $taskJob.target -Algorithm SHA256).Hash -ne $taskJob.old){throw 'Old canonical changed from protected baseline'}}
}
foreach($taskJob in $taskJobs){
 if(-not(Test-Path -LiteralPath $taskJob.source)){continue}
 if(Test-Path -LiteralPath $taskJob.target){
  $taskSuffix=if($taskJob.kind -eq 'gacha'){'_before_promo.png'}else{'_before_full_forest.png'}
  $taskArchive=Join-Path ([IO.Path]::GetDirectoryName($taskJob.target)) ('iterations/'+[IO.Path]::GetFileNameWithoutExtension($taskJob.target)+$taskSuffix)
  Assert-TaskPreviewPath $taskArchive
  if(Test-Path -LiteralPath $taskArchive){throw 'Distinct prior version already exists; preserve and inspect'}
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($taskArchive))|Out-Null
  Move-Item -LiteralPath $taskJob.target -Destination $taskArchive
  if((Get-FileHash -LiteralPath $taskArchive -Algorithm SHA256).Hash -ne $taskJob.old){throw 'Archived old source failed verification'}
  $taskJob.archive=$taskArchive
 }
 Move-Item -LiteralPath $taskJob.source -Destination $taskJob.target
 if((Get-FileHash -LiteralPath $taskJob.target -Algorithm SHA256).Hash -ne $taskJob.expected){throw 'Final PNG failed hash verification'}
}
$taskChangedPaths=@($taskJobs.path)
foreach($taskOriginal in $taskBaseline.protected_existing_views){if($taskChangedPaths -contains $taskOriginal.file){continue};if((Get-FileHash -LiteralPath (Join-Path $taskRoot $taskOriginal.file) -Algorithm SHA256).Hash -ne $taskOriginal.sha256){throw ('Unrelated view changed: '+$taskOriginal.file)}}
$taskTen=Join-Path $taskRoot 'core_pages/08_gacha_ten_result.png'
if((Get-Item -LiteralPath $taskTen).Length -ne 240604 -or (Get-FileHash -LiteralPath $taskTen -Algorithm SHA256).Hash -ne '1C34FFFA67145E1DD6A75D7E19E79E5E879322BAFCF80D792AD2BBDBC3C179BC'){throw 'Protected ten-result changed'}
[ordered]@{request_id='REQ-20261012-GACHA-MAP-REFINEMENT';status='ADOPTED_SAME_REVIEWED_BYTES';canonical_adoptions=$taskJobs;retained_unrelated_views=23;ten_result='UNCHANGED_BYTES_AND_SHA';rule='Individual checked same-volume moves; one physical new PNG per canonical view; distinct prior artwork retained in iterations'}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $taskRoot 'gacha_refinement/adoption.json') -Encoding utf8
[pscustomobject]@{reviewed_png_adopted=$taskJobs.Count;unrelated_png_retained=23;ten_result='UNCHANGED'}
