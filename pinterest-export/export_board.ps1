<#
Export every pin of a public Pinterest board (incl. sections) - no installs.
Usage:
  .\export_board.ps1
  .\export_board.ps1 -Cookies cookies.txt
  .\export_board.ps1 -NoImages
Writes pins\<pin_id>.<ext> and pins.json next to this script.
#>
param(
  [string]$Board = "spirit0447/halo-raves",
  [string]$BoardId = "1137440518329425584",
  [string]$Cookies,
  [switch]$NoImages
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"
$Here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$Base = "https://www.pinterest.com"
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
$parts = $Board.Trim("/").Split("/")
$User = $parts[0]; $Slug = $parts[1]
$Src = "/$User/$Slug/"

$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$Session.UserAgent = $UA
if ($Cookies) {
  $cpath = if ([IO.Path]::IsPathRooted($Cookies)) { $Cookies } else { Join-Path (Get-Location).Path $Cookies }
  foreach ($line in Get-Content $cpath) {
    if ($line -match '^#HttpOnly_') { $line = $line.Substring(10) }
    elseif ($line -match '^\s*#' -or $line.Trim() -eq "") { continue }
    $f = $line -split "`t"
    if ($f.Count -lt 7) { continue }
    $c = New-Object System.Net.Cookie($f[5], $f[6], $f[2], $f[0].TrimStart('.'))
    $Session.Cookies.Add($c)
  }
}
try { Invoke-WebRequest -Uri "$Base/" -WebSession $Session -UseBasicParsing | Out-Null } catch { Write-Host "Warning: home page load failed: $($_.Exception.Message)" }
$Csrf = ($Session.Cookies.GetCookies($Base) | Where-Object { $_.Name -eq "csrftoken" } | Select-Object -First 1).Value

function Get-Resource([string]$Name, [hashtable]$Options) {
  $data = @{ options = $Options; context = @{} } | ConvertTo-Json -Depth 10 -Compress
  $ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $url = "$Base/resource/$Name/get/?source_url=" + [Uri]::EscapeDataString($Src) + "&data=" + [Uri]::EscapeDataString($data) + "&_=$ts"
  $h = @{ "Accept" = "application/json, text/javascript, */*; q=0.01"; "X-Requested-With" = "XMLHttpRequest";
          "X-Pinterest-AppState" = "active"; "Referer" = "$Base$Src"; "Accept-Language" = "en-US,en;q=0.9" }
  if ($Csrf) { $h["X-CSRFToken"] = $Csrf }
  for ($try = 1; $try -le 3; $try++) {
    try {
      $r = Invoke-RestMethod -Uri $url -Headers $h -WebSession $Session -UseBasicParsing
      return $r.resource_response
    } catch {
      if ($try -eq 3) { Write-Host "  $Name failed: $($_.Exception.Message)"; return $null }
      Start-Sleep -Seconds (2 * $try)
    }
  }
}

function Get-Paged([string]$Name, [hashtable]$Options) {
  $bookmark = $null; $out = New-Object System.Collections.ArrayList
  while ($true) {
    $o = $Options.Clone()
    if ($bookmark) { $o["bookmarks"] = @($bookmark) }
    $rr = Get-Resource $Name $o
    if (-not $rr -or -not $rr.data) { break }
    foreach ($i in @($rr.data)) { [void]$out.Add($i) }
    $bookmark = $rr.bookmark
    if (-not $bookmark -or $bookmark -eq "-end-") { break }
    Start-Sleep -Milliseconds 600
  }
  return ,$out
}

function Get-BestImage($pin) {
  if (-not $pin.images) { return $null }
  foreach ($k in "orig", "originals", "1200x", "736x", "474x", "236x") {
    $v = $pin.images.$k
    if ($v -and $v.url) { return $v.url }
  }
  return $null
}

$Pins = [ordered]@{}
function Add-Pin($p, $section) {
  if (-not $p.id) { return }
  if ($p.type -and $p.type -ne "pin") { return }
  $id = [string]$p.id
  if ($Pins.Contains($id)) {
    if ($section -and -not $Pins[$id].section) { $Pins[$id].section = $section }
    return
  }
  $title = if ($p.title) { $p.title } else { $p.grid_title }
  $Pins[$id] = [ordered]@{ id = $id; created_at = $p.created_at; title = $title; description = $p.description;
                           link = $p.link; image_url = (Get-BestImage $p); section = $section; file = $null }
}

$bd = Get-Resource "BoardResource" @{ username = $User; slug = $Slug; field_set_key = "detailed" }
$count = 0
if ($bd -and $bd.data -and $bd.data.id) { $BoardId = [string]$bd.data.id; $count = [int]$bd.data.pin_count; Write-Host "Board: $($bd.data.name) id=$BoardId pins~$count" }
else { Write-Host "Board lookup failed; using board id $BoardId" }

# Logged-out feed caps inconsistently, so try several page sizes and merge.
foreach ($size in 250, 100, 50, 25) {
  $items = Get-Paged "BoardFeedResource" @{ board_id = $BoardId; board_url = $Src; page_size = $size; field_set_key = "react_grid_pin"; layout = "default" }
  foreach ($p in $items) { Add-Pin $p $null }
  Write-Host "Feed page_size=$size : got $($items.Count), total unique $($Pins.Count)"
  if ($count -gt 0 -and $Pins.Count -ge $count) { break }
}

$sections = Get-Paged "BoardSectionsResource" @{ board_id = $BoardId; page_size = 25 }
foreach ($s in $sections) {
  if (-not $s.id) { continue }
  $before = $Pins.Count
  foreach ($p in (Get-Paged "BoardSectionPinsResource" @{ section_id = [string]$s.id; page_size = 250 })) { Add-Pin $p $s.title }
  Write-Host "Section '$($s.title)': +$($Pins.Count - $before) new"
}

Write-Host "Total unique pins: $($Pins.Count)"
if ($count -gt 0 -and $Pins.Count -lt $count) { Write-Host "NOTE: fewer than the board count. Try again with -Cookies cookies.txt" }

$OutDir = Join-Path $Here "pins"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if (-not $NoImages) {
  $n = 0
  foreach ($p in $Pins.Values) {
    $n++
    if (-not $p.image_url) { continue }
    $ext = [IO.Path]::GetExtension(($p.image_url -split '\?')[0]); if (-not $ext) { $ext = ".jpg" }
    $path = Join-Path $OutDir ($p.id + $ext)
    $p.file = "pins/" + $p.id + $ext
    if (Test-Path $path) { continue }
    try { Invoke-WebRequest -Uri $p.image_url -OutFile $path -WebSession $Session -UseBasicParsing }
    catch { Write-Host "  image failed $($p.id): $($_.Exception.Message)" }
    if ($n % 25 -eq 0) { Write-Host "  $n/$($Pins.Count) images" }
  }
}
$json = @($Pins.Values | Sort-Object { $_.id }) | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $Here "pins.json"), $json, (New-Object Text.UTF8Encoding($false)))
Write-Host "Done. Wrote pins.json and pins folder."
