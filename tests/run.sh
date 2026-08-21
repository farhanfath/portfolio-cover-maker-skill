#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BROWSER="$("$HERE/../scripts/find-browser.sh")" || { echo "FAIL :: no Chromium-based browser found"; exit 1; }

# On Git Bash/MSYS, $HERE is a POSIX-style path (e.g. /d/foo). A native Windows
# Chrome binary can't resolve that in a file:// URL, so convert via cygpath
# when available; elsewhere (Linux/macOS) HERE is already a native path.
if command -v cygpath >/dev/null 2>&1; then
  URL="file:///$(cygpath -m "$HERE/test.html")"
else
  URL="file://$HERE/test.html"
fi
OUT="$("$BROWSER" --headless=new --disable-gpu --do-not-de-elevate --virtual-time-budget=5000 \
       --dump-dom "$URL" 2>/dev/null)"

echo "$OUT" | grep -oE '(PASS|FAIL|TOTAL) [^<]*' || true
if ! echo "$OUT" | grep -qE 'TOTAL [0-9]+ FAILED [0-9]+'; then
  echo "FAIL :: no test output captured :: browser=$BROWSER url=$URL"
  exit 1
fi
if echo "$OUT" | grep -q 'FAIL ::'; then echo "--- unit tests FAILED ---"; exit 1; fi
echo "--- unit tests passed ---"
