# One-liner:  irm https://raw.githubusercontent.com/HALORAVES/halo-bot-files/main/pinterest-export/run.ps1 | iex
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Work = Join-Path $env:TEMP ("halo-pins-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force -Path $Work | Out-Null
Write-Host "Working in $Work"
$Script = Join-Path $Work "export_board.ps1"
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/HALORAVES/halo-bot-files/main/pinterest-export/export_board.ps1" -OutFile $Script

$exe = (Get-Process -Id $PID).Path
& $exe -NoProfile -ExecutionPolicy Bypass -File $Script

$Json = Join-Path $Work "pins.json"
if (-not (Test-Path $Json)) { Write-Host "Export failed: no pins.json" -ForegroundColor Red; return }
$Zip = Join-Path $Work "halo-pins.zip"
Compress-Archive -Path $Json, (Join-Path $Work "pins") -DestinationPath $Zip -Force
Write-Host ("Zip size: {0:N1} MB" -f ((Get-Item $Zip).Length / 1MB))

function Send-File([string]$Url, [string[]]$CurlArgs, [hashtable]$Form) {
  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  if ($curl) { return (& $curl.Source -s -m 600 @CurlArgs $Url | Out-String).Trim() }
  if ($PSVersionTable.PSVersion.Major -ge 7) { return (Invoke-RestMethod -Uri $Url -Method Post -Form $Form | Out-String).Trim() }
  throw "Needs curl.exe (Windows 10+) or PowerShell 7"
}

$Link = $null
Write-Host "Uploading (litterbox.catbox.moe, kept 72h)..."
try {
  $r = Send-File "https://litterbox.catbox.moe/resources/internals/api.php" @("-F","reqtype=fileupload","-F","time=72h","-F","fileToUpload=@$Zip") @{ reqtype = "fileupload"; time = "72h"; fileToUpload = (Get-Item $Zip) }
  if ($r -match '^https://\S+$') { $Link = $r } else { Write-Host "litterbox said: $r" }
} catch { Write-Host "litterbox failed: $($_.Exception.Message)" }
if (-not $Link) {
  Write-Host "Trying backup (tmpfiles.org, kept 60 min)..."
  try {
    $r = Send-File "https://tmpfiles.org/api/v1/upload" @("-F","file=@$Zip;filename=halo-pins.zip") @{ file = (Get-Item $Zip) }
    $u = ($r | ConvertFrom-Json).data.url
    if ($u) { $Link = $u -replace '^https?://tmpfiles\.org/', 'https://tmpfiles.org/dl/' }
  } catch { Write-Host "tmpfiles failed: $($_.Exception.Message)" }
}

Write-Host ""
if ($Link) {
  try { Set-Clipboard -Value $Link } catch {}
  Write-Host "==============================================================" -ForegroundColor Yellow
  Write-Host "  COPY THIS LINK AND PASTE IT TO HALO: $Link" -ForegroundColor Yellow
  Write-Host "  (already copied to your clipboard)" -ForegroundColor Yellow
  Write-Host "==============================================================" -ForegroundColor Yellow
} else {
  Write-Host "Upload failed. Your zip is here; drag it into the chat or GitHub:" -ForegroundColor Red
  Write-Host "  $Zip" -ForegroundColor Red
  try { Start-Process explorer.exe "/select,`"$Zip`"" } catch {}
}
