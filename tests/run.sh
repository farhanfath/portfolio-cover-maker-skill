#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BROWSER="$("$HERE/../scripts/find-browser.sh")" || { echo "FAIL :: no Chromium-based browser found"; exit 1; }

OUT="$("$BROWSER" --headless=new --disable-gpu --virtual-time-budget=5000 \
       --dump-dom "file://$HERE/test.html" 2>/dev/null)"

echo "$OUT" | grep -oE '(PASS|FAIL|TOTAL) [^<]*' || true
if echo "$OUT" | grep -q 'FAIL ::'; then echo "--- unit tests FAILED ---"; exit 1; fi
echo "--- unit tests passed ---"
