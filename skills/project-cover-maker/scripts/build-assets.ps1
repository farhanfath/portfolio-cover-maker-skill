$ErrorActionPreference = 'Stop'
$root  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$fonts = Join-Path $root 'assets\fonts'
$decor = Join-Path $root 'assets\decor'

function ConvertTo-B64($p) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) }
# Windows PowerShell 5.1's Out-File -Encoding utf8 always prepends a UTF-8
# BOM; bash's generator writes no BOM. Write via .NET with a BOM-less
# UTF8Encoding so both generators produce byte-identical output.
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
function Write-Utf8NoBom($path, $text) { [IO.File]::WriteAllText($path, $text, $utf8NoBom) }

$css = @('/* GENERATED oleh scripts/build-assets.ps1. Jangan diedit tangan. */')
$faces = @(
  @{ fam='Outfit'; w=700; f='Outfit-Bold.woff2' },
  @{ fam='Outfit'; w=600; f='Outfit-SemiBold.woff2' },
  @{ fam='Inter';  w=400; f='Inter-Regular.woff2' },
  @{ fam='Inter';  w=500; f='Inter-Medium.woff2' }
)
foreach ($f in $faces) {
  $b64 = ConvertTo-B64 (Join-Path $fonts $f.f)
  $css += '@font-face{font-family:"' + $f.fam + '";font-style:normal;font-weight:' + $f.w +
          ';font-display:block;src:url(data:font/woff2;base64,' + $b64 + ') format("woff2");}'
}
Write-Utf8NoBom (Join-Path $root 'assets\fonts.css') (($css -join "`n") + "`n")

$shapes = @{ brush='brush-01.svg'; blob='blob-01.svg'; dots='dots.svg'; grid='grid.svg' }
$js = @('// GENERATED oleh scripts/build-assets.ps1. Jangan diedit tangan.',
        '(function (global) {',
        '  var NS = global.CoverMaker = global.CoverMaker || {};',
        '  var SHAPES = {')
foreach ($k in @('brush','blob','dots','grid')) {
  $svg = (Get-Content (Join-Path $decor $shapes[$k]) -Raw) -replace "`r?`n", ''
  # Strip xmlns: unnecessary for inline SVG parsed as HTML foreign content
  # (the HTML5 parser auto-detects <svg> and switches namespace on its own),
  # and its "http://www.w3.org/2000/svg" value would otherwise trip the
  # no-external-reference check.
  $svg = $svg -replace ' xmlns="http://www\.w3\.org/2000/svg"', ''
  $svg = $svg -replace 'id="', ('id="cm-' + $k + '-') -replace 'url\(#', ('url(#cm-' + $k + '-')
  $svg = $svg -replace '\\', '\\\\' -replace "'", "\'"
  $js += "    $k`: '$svg',"
}
$js += '  };'
$js += @"
  var BY_ARCHETYPE = {
    'split-right': 'brush',
    'split-left': 'brush',
    'centered': 'dots',
    'diagonal': 'grid',
    'scatter': 'blob',
    'duo': 'brush',
    'solo': 'blob'
  };
  function forArchetype(a) { return BY_ARCHETYPE[a] || 'brush'; }
  function resolve(setting, archetype) {
    if (setting === 'none') return null;
    var key = (!setting || setting === 'auto') ? forArchetype(archetype) : setting;
    return SHAPES[key] || null;
  }
  NS.decor = { SHAPES: SHAPES, forArchetype: forArchetype, resolve: resolve };
})(window);
"@
Write-Utf8NoBom (Join-Path $root 'assets\js\decor.js') (($js -join "`n") + "`n")

Write-Output 'generated: assets/fonts.css, assets/js/decor.js'
