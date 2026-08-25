$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$browser = & "$here\..\skills\project-cover-maker\scripts\find-browser.ps1"
if (-not $browser) { Write-Output 'no browser found'; exit 1 }
$u = ($here -replace '\\','/')

foreach ($p in @(@('home','Home'), @('chat','Chat'), @('detail','Detail'))) {
  & $browser --headless=new --disable-gpu --hide-scrollbars `
    --window-size=1080,2340 --virtual-time-budget=4000 `
    "--screenshot=$here\fixture\$($p[0]).png" `
    "file:///$u/fixture/_source.html?screen=$($p[1])" | Out-Null
}
Get-ChildItem "$here\fixture\*.png" | Select-Object Name, Length
