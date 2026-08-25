# Mencetak path binary browser Chromium-based. exit 1 kalau tidak ada.
$ErrorActionPreference = 'SilentlyContinue'

foreach ($n in @('chrome','msedge','chromium')) {
  $c = (Get-Command $n).Source
  if ($c) { Write-Output $c; exit 0 }
}

$candidates = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
)
foreach ($p in $candidates) {
  if (Test-Path $p) { Write-Output $p; exit 0 }
}
exit 1
