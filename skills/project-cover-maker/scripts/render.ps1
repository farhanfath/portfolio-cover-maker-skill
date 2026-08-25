param([string]$CoverJson = 'cover.json')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $CoverJson)) { Write-Output "error: $CoverJson not found"; exit 1 }

# Windows PowerShell 5.1's Out-File -Encoding utf8 always prepends a UTF-8
# BOM; bash's generator writes no BOM. Write via .NET with a BOM-less
# UTF8Encoding so both generators produce byte-identical output.
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
function Write-Utf8NoBom($path, $text) { [IO.File]::WriteAllText($path, $text, $utf8NoBom) }

# Get-Content -Raw with no -Encoding falls back to the system ANSI codepage
# for BOM-less files on Windows PowerShell 5.1, mangling any non-ASCII byte
# (e.g. an em dash in a source comment) into mojibake. Read explicitly as
# UTF-8 (BOM or not) instead, matching how bash's `cat` passes UTF-8 bytes
# through untouched.
function Read-Utf8($path) { [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) }

$root    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$srcDir  = Split-Path -Parent (Resolve-Path $CoverJson)
$dataRaw = Read-Utf8 (Resolve-Path $CoverJson).Path

function Get-Mime($p) {
  switch ([IO.Path]::GetExtension($p).ToLower()) {
    '.png'  { 'image/png' }    '.jpg' { 'image/jpeg' }  '.jpeg' { 'image/jpeg' }
    '.webp' { 'image/webp' }   '.svg' { 'image/svg+xml' }
    default { 'application/octet-stream' }
  }
}

# Cheap sanity check on the file's actual bytes, keyed off its extension.
# Existence alone (spec §7.2: "tidak ada/tidak terbaca") does not catch a
# text file with a .png extension (e.g. an un-pulled git-lfs pointer) - that
# used to sail straight through and only surface, much later and much less
# clearly, as a blank render or a hung headless Chrome. This names the
# actual bad file up front instead.
function Test-ImageMagic($bytes, $ext) {
  switch ($ext) {
    '.png' {
      return ($bytes.Length -ge 8 -and $bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50 -and
              $bytes[2] -eq 0x4E -and $bytes[3] -eq 0x47 -and $bytes[4] -eq 0x0D -and
              $bytes[5] -eq 0x0A -and $bytes[6] -eq 0x1A -and $bytes[7] -eq 0x0A)
    }
    { $_ -eq '.jpg' -or $_ -eq '.jpeg' } {
      return ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8)
    }
    '.webp' {
      return ($bytes.Length -ge 12 -and $bytes[0] -eq 0x52 -and $bytes[1] -eq 0x49 -and
              $bytes[2] -eq 0x46 -and $bytes[3] -eq 0x46 -and $bytes[8] -eq 0x57 -and
              $bytes[9] -eq 0x45 -and $bytes[10] -eq 0x42 -and $bytes[11] -eq 0x50)
    }
    '.svg' {
      $head = [Text.Encoding]::UTF8.GetString($bytes, 0, [Math]::Min(512, $bytes.Length))
      return ($head -match '<svg' -or $head -match '<\?xml')
    }
    default { return $true }   # tipe tak dikenal: mime_of sudah default ke octet-stream, tidak ada acuan untuk dicek
  }
}

# Diurutkan terpanjang-lebih-dulu: kalau satu nama file adalah substring dari
# nama file lain (mis. "a.png" di dalam "xa.png"), mengganti yang pendek dulu
# akan merusak substitusi yang panjang.
$srcs = [regex]::Matches($dataRaw, '"(?:src|logo)"\s*:\s*"([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique |
        Sort-Object -Property Length -Descending
foreach ($rel in $srcs) {
  $abs = Join-Path $srcDir $rel
  if (-not (Test-Path $abs)) { Write-Output "error: image not found: $rel"; exit 1 }
  $bytes = [IO.File]::ReadAllBytes($abs)
  $ext = [IO.Path]::GetExtension($abs).ToLower()
  if (-not (Test-ImageMagic $bytes $ext)) {
    Write-Output "error: image is not a valid $ext (bad file signature): $rel"
    exit 1
  }
  $uri = 'data:' + (Get-Mime $abs) + ';base64,' + [Convert]::ToBase64String($bytes)
  $dataRaw = $dataRaw.Replace('"' + $rel + '"', '"' + $uri + '"')
}

$styles = Read-Utf8 (Join-Path $root 'assets\fonts.css')
$coverCss = Join-Path $root 'assets\cover.css'
if (Test-Path $coverCss) { $styles += "`n" + (Read-Utf8 $coverCss) }

$scripts = @('palette.js','validate.js','layout.js','decor.js','render.js') |
  ForEach-Object { Read-Utf8 (Join-Path $root "assets\js\$_") }
$scripts = $scripts -join "`n"

$browser = & (Join-Path $root 'scripts\find-browser.ps1')

$outDir = ([regex]::Match($dataRaw, '"dir"\s*:\s*"([^"]*)"')).Groups[1].Value
if (-not $outDir) { $outDir = 'cover-output' }
if (-not [IO.Path]::IsPathRooted($outDir)) { $outDir = Join-Path $srcDir $outDir }
New-Item -ItemType Directory -Force $outDir | Out-Null

$scale = ([regex]::Match($dataRaw, '"scale"\s*:\s*(\d+)')).Groups[1].Value
if (-not $scale) { $scale = '2' }

$planHtml = Join-Path $outDir '_plan.html'
$planParts = @('<!doctype html><meta charset="utf-8"><pre id="out"></pre><script>',
  (Read-Utf8 (Join-Path $root 'assets\js\validate.js')),
  (Read-Utf8 (Join-Path $root 'assets\js\layout.js')),
  "var D = $dataRaw;", @"
  try {
    var v = CoverMaker.validate.validate(D);
    document.getElementById('out').textContent =
      'SET ' + CoverMaker.layout.renderSet(v.data).join(',') +
      '\n' + v.warnings.map(function (w) { return 'WARN ' + w; }).join('\n');
  } catch (e) { document.getElementById('out').textContent = 'ERROR ' + e.message; }
</script>
"@)
Write-Utf8NoBom $planHtml ($planParts -join "`n")

$layouts = @('split-right')
if ($browser) {
  # Windows PowerShell 5.1's pipeline capture of an external GUI-subsystem
  # process (chrome.exe) unreliably returns empty output, and on this kind of
  # elevated shell chrome silently does nothing at all unless it is told not
  # to de-elevate itself. Both issues are already solved the same way in
  # tests/run.ps1: --do-not-de-elevate plus Start-Process with OS-level file
  # redirection instead of the call operator's own output capture.
  $planUrl = "file:///$(($planHtml -replace '\\','/'))"
  $outFile = [System.IO.Path]::GetTempFileName()
  $errFile = [System.IO.Path]::GetTempFileName()
  $planOut = ""
  try {
    $argStr = '--headless=new --disable-gpu --do-not-de-elevate --virtual-time-budget=4000 --dump-dom "' + $planUrl + '"'
    Start-Process -FilePath $browser -ArgumentList $argStr -NoNewWindow -Wait `
      -RedirectStandardOutput $outFile -RedirectStandardError $errFile -ErrorAction Stop
    $planOut = Get-Content -Path $outFile -Raw -ErrorAction SilentlyContinue
    if (-not $planOut) { $planOut = "" }
    # chrome.exe's redirected stdout carries CRLF line endings on Windows;
    # strip the CRs so a layout name split off the end (e.g. "solo`r") is not
    # mistaken for a distinct, invalid layout.
    $planOut = $planOut -replace "`r", ""
  } catch {
    $planOut = ""
  } finally {
    Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
  }
  # --dump-dom echoes the whole document, including the raw <script> source
  # that produced the result (which itself contains the literal strings
  # 'SET ', 'WARN ' and 'ERROR ' as JS string literals). Matching the full
  # dump would pick up those tokens from the source text too, so cut the dump
  # at the first <script> tag and only inspect the executed part before it.
  $cut = $planOut.IndexOf('<script>')
  $planResult = if ($cut -ge 0) { $planOut.Substring(0, $cut) } else { $planOut }
  if ($planResult -match 'ERROR ([^<]*)') { Write-Output "ERROR $($Matches[1])"; exit 1 }
  [regex]::Matches($planResult, 'WARN [^<]*') | ForEach-Object { Write-Output $_.Value }
  $layouts = ([regex]::Match($planResult, 'SET ([^<\n]*)')).Groups[1].Value -split ','
}
Remove-Item $planHtml -Force -ErrorAction SilentlyContinue

$w = 1600 * [int]$scale; $h = 900 * [int]$scale
$tpl = Read-Utf8 (Join-Path $root 'assets\template.html')

foreach ($layout in $layouts) {
  $page = Join-Path $outDir "render-$layout.html"
  $html = $tpl.Replace('__STYLES__', $styles).Replace('__SCRIPTS__', $scripts).
               Replace('__COVER_DATA__', $dataRaw).Replace('__LAYOUT__', $layout).
               Replace('__SCALE__', $scale)
  Write-Utf8NoBom $page $html
  Write-Output "html: $page"
  if (-not $browser) { continue }
  $pngPath = Join-Path $outDir "$layout.png"
  # chrome.exe writes a "N bytes written to file ..." line to stderr on every
  # screenshot. With $ErrorActionPreference = 'Stop' in effect, PowerShell's
  # own `2>` redirection on a native command wraps each stderr line in a
  # terminating NativeCommandError (same class of issue tests/run.ps1 already
  # documents for stdout capture) - it would abort the whole render instead of
  # just staying quiet. Route both streams through Start-Process to the NUL
  # device instead, bypassing PowerShell's stream-wrapping entirely (bash's
  # equivalent call redirects both streams too, so this keeps parity).
  #
  # --dump-dom alongside --screenshot in the same invocation: cover.js
  # (assets/js/render.js) sets data-ready="1" on <html> when it finishes, or
  # data-ready="error" (plus data-error="...") when it catches its own
  # failure. Without reading this back, a render that fails partway through
  # (corrupt hero image, bad logo, timed-out virtual-time-budget) still
  # produces a screenshot and gets reported as a success.
  $argStr = '--headless=new --disable-gpu --do-not-de-elevate --hide-scrollbars --force-device-scale-factor=1 ' +
            "--virtual-time-budget=8000 --window-size=`"$w,$h`" " +
            '"--screenshot=' + $pngPath + '" --dump-dom ' +
            '"file:///' + ($page -replace '\\','/') + '"'
  # Start-Process refuses identical redirect targets for stdout/stderr, so
  # each gets its own throwaway temp file.
  $shotOutFile = [System.IO.Path]::GetTempFileName()
  $shotErrFile = [System.IO.Path]::GetTempFileName()
  $domOut = ""
  $procFailed = $false
  try {
    Start-Process -FilePath $browser -ArgumentList $argStr -NoNewWindow -Wait `
      -RedirectStandardOutput $shotOutFile -RedirectStandardError $shotErrFile -ErrorAction Stop
    $domOut = Get-Content -Path $shotOutFile -Raw -ErrorAction SilentlyContinue
    if (-not $domOut) { $domOut = "" }
    $domOut = $domOut -replace "`r", ""
  } catch {
    # Deferred finding folded in here: this used to be an empty catch block,
    # so a Start-Process failure (e.g. the browser path stopped existing
    # between find-browser.ps1 running and now) still fell through to the
    # unconditional "png:" line below for a PNG that was never written.
    $procFailed = $true
  } finally {
    Remove-Item $shotOutFile, $shotErrFile -ErrorAction SilentlyContinue
  }
  if ($procFailed) {
    Write-Output "error: render for layout '$layout' failed to launch the browser"
    Remove-Item $pngPath -ErrorAction SilentlyContinue
    exit 1
  }
  # Same reasoning as the plan-detection cut above: the dumped DOM includes
  # the raw <script> source, which contains the literal strings 'data-ready'
  # and 'data-error' as JS string/attribute-name literals. Only trust the
  # part of the dump before the first <script> tag.
  $cut = $domOut.IndexOf('<script>')
  $domHead = if ($cut -ge 0) { $domOut.Substring(0, $cut) } else { $domOut }
  if ($domHead -match 'data-ready="error"') {
    $errMsg = if ($domHead -match 'data-error="([^"]*)"') { $Matches[1] } else { 'unknown error' }
    Write-Output "error: render for layout '$layout' failed in-page: $errMsg"
    Remove-Item $pngPath -ErrorAction SilentlyContinue
    exit 1
  }
  if ($domHead -notmatch 'data-ready="1"') {
    Write-Output ("error: render for layout '$layout' did not finish (no data-ready=""1"" found; " +
                   "the page may have exceeded --virtual-time-budget or the browser crashed)")
    Remove-Item $pngPath -ErrorAction SilentlyContinue
    exit 1
  }
  Write-Output "png:  $pngPath"
}

if (-not $browser) {
  Write-Output 'warn: no Chromium-based browser found. The HTML pages above are fully'
  Write-Output 'warn: self-contained - open one in any browser and screenshot it manually.'
  exit 2
}
