param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
  [string[]]$CardId = @(),
  [switch]$Force,
  [switch]$IncludePending
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$CardsPath = Join-Path $ProjectRoot "config/tables/cards.csv"
$VoicesPath = Join-Path $ProjectRoot "config/tables/card_skill_voices.csv"
$ManifestPath = Join-Path $ProjectRoot "assets/audio/voices/skills/zh_cn/manifest.json"
$HexSize = 43.0

$VoiceDisplayNames = @{
  huihui = "Microsoft Huihui"
  yaoyao = "Microsoft Yaoyao"
  kangkang = "Microsoft Kangkang"
}


function Read-ThreeRowCsv([string]$Path) {
  $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.UTF8Encoding]::new($false))
  if ($lines.Count -lt 4) {
    throw "Configuration table has no runtime rows: $Path"
  }
  $headers = $lines[0].Split(',')
  return @($lines[3..($lines.Count - 1)] | ConvertFrom-Csv -Header $headers)
}


function Get-RangeLabel([double]$AttackRange) {
  if ($AttackRange -le $HexSize * 1.5) {
    return ""
  }
  if ($AttackRange -le $HexSize * 2.6) {
    return [string]::Concat([char]0x8FDC, [char]0x7A0B)
  }
  return [string]::Concat([char]0x8D85, [char]0x8FDC, [char]0x7A0B)
}


function Get-SpokenText($Card) {
  $skill = ([string]$Card.skill_text).Trim()
  if ([string]::IsNullOrWhiteSpace($skill)) {
    return ""
  }
  $rangeLabel = Get-RangeLabel ([double]$Card.attack_range)
  if ([string]::IsNullOrWhiteSpace($rangeLabel)) {
    return $skill
  }
  return [string]::Concat($rangeLabel, [char]0x3002, $skill)
}


function Get-SignedPercent([double]$Value) {
  $rounded = [Math]::Round($Value, 2)
  if ($rounded -ge 0) {
    return "+$rounded%"
  }
  return "$rounded%"
}


function Get-TextSha256([string]$Text) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  }
  finally {
    $sha.Dispose()
  }
}


function Await-WinRtResult($Operation, [Type]$ResultType) {
  $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object {
      $_.Name -eq "AsTask" -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1
    } |
    Select-Object -First 1
  if ($null -eq $method) {
    throw "Unable to find Windows Runtime AsTask<T> helper."
  }
  $task = $method.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
  $task.Wait()
  return $task.Result
}


function Write-SpeechWav($Synthesizer, [string]$Text, [double]$RatePct, [double]$PitchPct, [string]$OutputPath) {
  $escaped = [System.Security.SecurityElement]::Escape($Text)
  $rate = Get-SignedPercent $RatePct
  $pitch = Get-SignedPercent $PitchPct
  $ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'><prosody rate='$rate' pitch='$pitch'>$escaped</prosody></speak>"
  $stream = Await-WinRtResult ($Synthesizer.SynthesizeSsmlToStreamAsync($ssml)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
  try {
    $reader = [Windows.Storage.Streams.DataReader]::new($stream.GetInputStreamAt(0))
    try {
      [void](Await-WinRtResult ($reader.LoadAsync([uint32]$stream.Size)) ([uint32]))
      $bytes = New-Object byte[] ([int]$stream.Size)
      $reader.ReadBytes($bytes)
      [System.IO.File]::WriteAllBytes($OutputPath, $bytes)
    }
    finally {
      $reader.Dispose()
    }
  }
  finally {
    $stream.Dispose()
  }
}


Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]

$cards = Read-ThreeRowCsv $CardsPath
$voiceRows = Read-ThreeRowCsv $VoicesPath
$animalCards = @($cards | Where-Object { ([string]$_.art_path).Contains('/animals/') })
if ($animalCards.Count -ne 60) {
  throw "Expected 60 animal cards, found $($animalCards.Count)."
}
if ($voiceRows.Count -ne $animalCards.Count) {
  throw "Every animal needs one voice-production row: cards=$($animalCards.Count), rows=$($voiceRows.Count)."
}

$cardsById = @{}
foreach ($card in $animalCards) {
  $cardsById[[string]$card.id] = $card
}
foreach ($row in $voiceRows) {
  if (-not $cardsById.ContainsKey([string]$row.card_id)) {
    throw "Voice row references a non-animal or missing card: $($row.card_id)"
  }
}

$allVoices = @([Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices)
$synthesizers = @{}
$generatedIds = [System.Collections.Generic.List[string]]::new()

foreach ($row in $voiceRows) {
  $id = [string]$row.card_id
  $status = [string]$row.status
  $spokenText = Get-SpokenText $cardsById[$id]
  if ($status -eq "silent_no_player_skill") {
    if (-not [string]::IsNullOrWhiteSpace($spokenText)) {
      throw "$id is marked silent but has visible skill information: $spokenText"
    }
    continue
  }
  if ([string]::IsNullOrWhiteSpace($spokenText)) {
    throw "$id has no player-visible skill information but is not marked silent."
  }
  $selectedById = $CardId.Count -eq 0 -or $CardId -contains $id
  $selectedByStatus = $status -in @("prototype_generated", "approved") -or ($IncludePending -and $status -eq "pending_review")
  if (-not $selectedById -or -not $selectedByStatus) {
    continue
  }
  $resourcePath = [string]$row.voice_path
  if (-not $resourcePath.StartsWith("res://assets/audio/voices/skills/zh_cn/")) {
    throw "Invalid voice resource path for ${id}: $resourcePath"
  }
  $outputPath = Join-Path $ProjectRoot $resourcePath.Substring(6).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $outputPath)) | Out-Null
  if ((Test-Path -LiteralPath $outputPath) -and -not $Force) {
    $generatedIds.Add($id)
    continue
  }

  $voiceKey = [string]$row.voice_name
  if (-not $VoiceDisplayNames.ContainsKey($voiceKey)) {
    throw "Unknown voice_name for ${id}: $voiceKey"
  }
  if (-not $synthesizers.ContainsKey($voiceKey)) {
    $voice = $allVoices | Where-Object { $_.DisplayName -eq $VoiceDisplayNames[$voiceKey] } | Select-Object -First 1
    if ($null -eq $voice) {
      throw "Required offline voice is not installed: $($VoiceDisplayNames[$voiceKey])"
    }
    $synth = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::new()
    $synth.Voice = $voice
    $synthesizers[$voiceKey] = $synth
  }
  Write-SpeechWav $synthesizers[$voiceKey] $spokenText ([double]$row.rate_pct) ([double]$row.pitch_pct) $outputPath
  if ((Get-Item -LiteralPath $outputPath).Length -le 128) {
    throw "Generated voice asset is empty: $outputPath"
  }
  $generatedIds.Add($id)
}

$manifestRows = foreach ($row in $voiceRows) {
  $id = [string]$row.card_id
  $spokenText = Get-SpokenText $cardsById[$id]
  $resourcePath = [string]$row.voice_path
  $assetPath = ""
  $assetHash = ""
  $durationReady = $false
  if (-not [string]::IsNullOrWhiteSpace($resourcePath)) {
    $assetPath = Join-Path $ProjectRoot $resourcePath.Substring(6).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    if (Test-Path -LiteralPath $assetPath) {
      $assetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $assetPath).Hash.ToLowerInvariant()
      $durationReady = (Get-Item -LiteralPath $assetPath).Length -gt 128
    }
  }
  [ordered]@{
    card_id = $id
    locale = [string]$row.locale
    spoken_text = $spokenText
    spoken_text_sha256 = Get-TextSha256 $spokenText
    voice_path = $resourcePath
    persona_id = [string]$row.persona_id
    voice_name = [string]$row.voice_name
    rate_pct = [double]$row.rate_pct
    pitch_pct = [double]$row.pitch_pct
    gain_db = [double]$row.gain_db
    status = [string]$row.status
    asset_sha256 = $assetHash
    asset_ready = $durationReady
    provider = "windows_onecore_offline"
  }
}

[System.IO.Directory]::CreateDirectory((Split-Path -Parent $ManifestPath)) | Out-Null
$manifest = [ordered]@{
  schema_version = 1
  generated_at_utc = [DateTime]::UtcNow.ToString("o")
  source_table = "config/tables/card_skill_voices.csv"
  card_source = "config/tables/cards.csv"
  generated_card_ids = @($generatedIds)
  voices = @($manifestRows)
}
[System.IO.File]::WriteAllText(
  $ManifestPath,
  ($manifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine,
  [System.Text.UTF8Encoding]::new($false)
)

foreach ($synth in $synthesizers.Values) {
  $synth.Dispose()
}

Write-Host "Voice manifest: $ManifestPath"
Write-Host "Generated or reused $($generatedIds.Count) voice assets."
