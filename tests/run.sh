#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BROWSER="$(bash "$HERE/../scripts/find-browser.sh")" || { echo "FAIL :: no Chromium-based browser found"; exit 1; }

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
if ! echo "$OUT" | grep -qE 'TOTAL [1-9][0-9]* FAILED [0-9]+'; then
  echo "FAIL :: no test output captured :: browser=$BROWSER url=$URL"
  exit 1
fi
if echo "$OUT" | grep -q 'FAIL ::'; then echo "--- unit tests FAILED ---"; exit 1; fi

# --- Test #5: halaman render benar-benar self-contained ---
OUTDIR="$HERE/../cover-output-test"
rm -rf "$OUTDIR"
bash "$HERE/../scripts/render.sh" "$HERE/fixture/cover.json" >/dev/null || {
  echo "FAIL :: render.sh exited non-zero"; exit 1; }

SELF_OK=1
for page in "$OUTDIR"/render-*.html; do
  [ -f "$page" ] || { echo "FAIL :: no render-*.html produced"; SELF_OK=0; break; }
  if grep -qE 'file://|http://|https://' "$page"; then
    echo "FAIL :: $(basename "$page") contains an external URL"; SELF_OK=0
  fi
  if grep -oE '(src|href)="[^"]*"' "$page" | grep -qv '="data:'; then
    echo "FAIL :: $(basename "$page") has a non-data: src/href"; SELF_OK=0
  fi
done
[ "$SELF_OK" -eq 1 ] && echo "PASS :: render pages are fully self-contained"
[ "$SELF_OK" -eq 1 ] || exit 1

echo "--- unit tests passed ---"
