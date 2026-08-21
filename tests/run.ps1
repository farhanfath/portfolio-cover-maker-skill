$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$browser = & "$here\..\scripts\find-browser.ps1"
if (-not $browser) { Write-Output "FAIL :: no Chromium-based browser found"; exit 1 }

$url = "file:///$($here -replace '\\','/')/test.html"

# Invoke via Start-Process with file-redirected stdout/stderr rather than the
# call operator's own output capture: Windows PowerShell's pipeline capture of
# an external GUI-subsystem process (chrome.exe) unreliably returns empty
# output here, while OS-level file redirection does not.
$outFile = [System.IO.Path]::GetTempFileName()
$errFile = [System.IO.Path]::GetTempFileName()
$text = ""
try {
  $argStr = '--headless=new --disable-gpu --do-not-de-elevate --virtual-time-budget=5000 --dump-dom "' + $url + '"'
  Start-Process -FilePath $browser -ArgumentList $argStr -NoNewWindow -Wait `
    -RedirectStandardOutput $outFile -RedirectStandardError $errFile -ErrorAction Stop
  $text = Get-Content -Path $outFile -Raw -ErrorAction SilentlyContinue
  if (-not $text) { $text = "" }
} catch {
  $text = ""
} finally {
  Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
}

[regex]::Matches($text, '(PASS|FAIL|TOTAL) [^<]*') | ForEach-Object { Write-Output $_.Value }
if ($text -notmatch 'TOTAL \d+ FAILED \d+') {
  Write-Output "FAIL :: no test output captured :: browser=$browser url=$url"
  exit 1
}
if ($text -match 'FAIL ::') { Write-Output "--- unit tests FAILED ---"; exit 1 }
Write-Output "--- unit tests passed ---"
