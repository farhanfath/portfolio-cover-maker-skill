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
if ($text -notmatch 'TOTAL [1-9]\d* FAILED \d+') {
  Write-Output "FAIL :: no test output captured :: browser=$browser url=$url"
  exit 1
}
if ($text -match 'FAIL ::') { Write-Output "--- unit tests FAILED ---"; exit 1 }

# --- Test #5: halaman render benar-benar self-contained ---
$outDir = Join-Path $here '..\cover-output-test'
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
& "$here\..\scripts\render.ps1" "$here\fixture\cover.json" | Out-Null

$selfOk = $true
$pages = Get-ChildItem (Join-Path $outDir 'render-*.html') -ErrorAction SilentlyContinue
if (-not $pages) { Write-Output 'FAIL :: no render-*.html produced'; exit 1 }
foreach ($p in $pages) {
  $t = Get-Content $p.FullName -Raw
  if ($t -match 'file://|http://|https://') {
    Write-Output "FAIL :: $($p.Name) contains an external URL"; $selfOk = $false
  }
  $bad = [regex]::Matches($t, '(src|href)="([^"]*)"') |
         Where-Object { $_.Groups[2].Value -notlike 'data:*' }
  if ($bad) { Write-Output "FAIL :: $($p.Name) has a non-data: src/href"; $selfOk = $false }
  # A CSS url(...) is neither an attribute nor necessarily schemed (a relative
  # path like url(decor/brush.svg) has no http/https/file to catch above), so
  # it needs its own check: only url(data:...) (embedded) and url(#...)
  # (an internal SVG fragment reference, e.g. the decor pattern fills) may
  # appear; anything else fetches something external.
  $goodUrl = '^url\([''"]?(data:|#)'
  $badUrls = [regex]::Matches($t, 'url\([^)]*\)') |
             Where-Object { $_.Value -notmatch $goodUrl }
  if ($badUrls) {
    Write-Output "FAIL :: $($p.Name) has a url(...) that is not url(data: or url(#"; $selfOk = $false
  }
}
if ($selfOk) { Write-Output 'PASS :: render pages are fully self-contained' } else { exit 1 }

# --- Test #6: fixture render end-to-end ---
$e2eOk = $true
$pngs = @(Get-ChildItem (Join-Path $outDir '*.png') -ErrorAction SilentlyContinue)
if ($pngs.Count -ne 4) { Write-Output "FAIL :: e2e expected 4 png, got $($pngs.Count)"; $e2eOk = $false }
foreach ($p in $pngs) {
  if ($p.Length -lt 81920) {
    Write-Output "FAIL :: e2e $($p.Name) is only $($p.Length)B (<80KB), render likely blank"
    $e2eOk = $false
  }
  $b = [IO.File]::ReadAllBytes($p.FullName)
  # [byte] -shl in Windows PowerShell 5.1 returns a [byte], silently truncating
  # any bits shifted past position 7 (e.g. 12 -shl 8 becomes 0, not 3072) - cast
  # each byte to [int] first so the shift produces the real 32-bit value.
  $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
  $h = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
  if ($w -ne 3200 -or $h -ne 1800) {
    Write-Output "FAIL :: e2e $($p.Name) is ${w}x${h}, expected 3200x1800"; $e2eOk = $false
  }
}
if ($e2eOk) { Write-Output 'PASS :: e2e render produced 4 valid 3200x1800 covers' } else { exit 1 }

Write-Output "--- unit tests passed ---"
