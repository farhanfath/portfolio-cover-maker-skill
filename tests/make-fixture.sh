#!/usr/bin/env bash
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
BROWSER="$(bash "$HERE/../skills/project-cover-maker/scripts/find-browser.sh")" || { echo "no browser found"; exit 1; }

# On Git Bash/MSYS, $HERE is a POSIX-style path (e.g. /d/foo). A native Windows
# Chrome binary can't resolve that in a file:// URL, so convert via cygpath
# when available; elsewhere (Linux/macOS) HERE is already a native path.
if command -v cygpath >/dev/null 2>&1; then
  FIXTURE_URL_BASE="file:///$(cygpath -m "$HERE/fixture")"
else
  FIXTURE_URL_BASE="file://$HERE/fixture"
fi

shot() {
  "$BROWSER" --headless=new --disable-gpu --hide-scrollbars \
    --window-size=1080,2340 --virtual-time-budget=4000 \
    --screenshot="$HERE/fixture/$1.png" \
    "$FIXTURE_URL_BASE/_source.html?screen=$2" >/dev/null 2>&1
}

shot home   Home
shot chat   Chat
shot detail Detail
ls -l "$HERE/fixture"/*.png
