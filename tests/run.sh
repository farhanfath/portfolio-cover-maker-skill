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
  # A CSS url(...) is neither an attribute nor necessarily schemed (a relative
  # path like url(decor/brush.svg) has no http/https/file to catch above), so
  # it needs its own check: only url(data:...) (embedded) and url(#...)
  # (an internal SVG fragment reference, e.g. the decor pattern fills) may
  # appear; anything else fetches something external.
  if grep -oE "url\([^)]*\)" "$page" | grep -qvE "^url\(['\"]?(data:|#)"; then
    echo "FAIL :: $(basename "$page") has a url(...) that is not url(data: or url(#"; SELF_OK=0
  fi
done
[ "$SELF_OK" -eq 1 ] && echo "PASS :: render pages are fully self-contained"
[ "$SELF_OK" -eq 1 ] || exit 1

# --- Test #6: fixture render end-to-end ---
E2E_OK=1
PNGS="$(ls "$OUTDIR"/*.png 2>/dev/null | wc -l | tr -d ' ')"
if [ "$PNGS" -ne 4 ]; then
  echo "FAIL :: e2e expected 4 png, got $PNGS"; E2E_OK=0
fi

for png in "$OUTDIR"/*.png; do
  [ -f "$png" ] || continue
  SIZE="$(wc -c < "$png" | tr -d ' ')"
  if [ "$SIZE" -lt 81920 ]; then
    echo "FAIL :: e2e $(basename "$png") is only ${SIZE}B (<80KB), render likely blank"; E2E_OK=0
  fi
  # Dimensi PNG: lebar = byte 17-20, tinggi = byte 21-24 (big-endian) di chunk IHDR.
  DIMS="$(od -An -tu1 -j16 -N8 "$png" | awk '{
    w = $1*16777216 + $2*65536 + $3*256 + $4;
    h = $5*16777216 + $6*65536 + $7*256 + $8;
    print w "x" h }')"
  if [ "$DIMS" != "3200x1800" ]; then
    echo "FAIL :: e2e $(basename "$png") is $DIMS, expected 3200x1800"; E2E_OK=0
  fi
done

[ "$E2E_OK" -eq 1 ] && echo "PASS :: e2e render produced 4 valid 3200x1800 covers"
[ "$E2E_OK" -eq 1 ] || exit 1

# --- Test #7: satu versi, dua file ---
# Rilis diumumkan lewat dua jalur yang punya nomor versinya masing-masing:
# plugin.json (dibaca Claude Code untuk menawarkan update) dan package.json
# (dibaca npm). Kalau salah satu lupa dinaikkan, separuh pengguna tidak pernah
# ditawari update dan tidak ada yang error - itu diam-diamnya berbahaya.
ver_of() {
  grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" | head -1 |
    sed -E 's/.*"([^"]*)"[[:space:]]*$/\1/'
}
PLUGIN_VER="$(ver_of "$HERE/../.claude-plugin/plugin.json")"
NPM_VER="$(ver_of "$HERE/../package.json")"
if [ -z "$PLUGIN_VER" ] || [ -z "$NPM_VER" ]; then
  echo "FAIL :: could not read version from plugin.json ('$PLUGIN_VER') or package.json ('$NPM_VER')"
  exit 1
fi
if [ "$PLUGIN_VER" != "$NPM_VER" ]; then
  echo "FAIL :: version drift :: plugin.json=$PLUGIN_VER package.json=$NPM_VER"
  exit 1
fi
echo "PASS :: plugin.json and package.json agree on version $PLUGIN_VER"

echo "--- unit tests passed ---"
