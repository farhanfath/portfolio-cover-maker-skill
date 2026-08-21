$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$browser = & "$here\..\scripts\find-browser.ps1"
if (-not $browser) { Write-Output "FAIL :: no Chromium-based browser found"; exit 1 }

$out = & $browser --headless=new --disable-gpu --virtual-time-budget=5000 --dump-dom "file:///$($here -replace '\\','/')/test.html"
$text = $out -join "`n"
[regex]::Matches($text, '(PASS|FAIL|TOTAL) [^<]*') | ForEach-Object { Write-Output $_.Value }
if ($text -match 'FAIL ::') { Write-Output "--- unit tests FAILED ---"; exit 1 }
Write-Output "--- unit tests passed ---"
