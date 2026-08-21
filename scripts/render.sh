#!/usr/bin/env bash
# Bangun halaman self-contained lalu screenshot lewat headless Chrome.
# Tugasnya murni mekanis: substitusi placeholder + panggil browser.
set -eu

COVER_JSON="${1:-cover.json}"
[ -f "$COVER_JSON" ] || { echo "error: $COVER_JSON not found"; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$(cd "$(dirname "$COVER_JSON")" && pwd)"

# On Git Bash/MSYS, POSIX-style paths (e.g. /d/foo) are unreadable to a native
# Windows chrome.exe inside a file:// URL, so convert via cygpath when
# available; elsewhere (Linux/macOS) the path is already native.
if command -v cygpath >/dev/null 2>&1; then
  file_url() { printf 'file:///%s' "$(cygpath -m "$1")"; }
else
  file_url() { printf 'file://%s' "$1"; }
fi

b64() {
  if base64 --help 2>&1 | grep -q -- '-w'; then base64 -w0 "$1"; else base64 -i "$1"; fi
}

mime_of() {
  case "${1##*.}" in
    png)  echo image/png ;;
    jpg|jpeg) echo image/jpeg ;;
    webp) echo image/webp ;;
    svg)  echo image/svg+xml ;;
    *)    echo application/octet-stream ;;
  esac
}

# Ubah tiap path gambar di cover.json menjadi data URI.
# Dikerjakan dengan node-free text processing: baca JSON apa adanya, lalu
# ganti setiap nilai "src" dengan data URI padanannya.
DATA_JSON="$(cat "$COVER_JSON")"
# Diurutkan terpanjang-lebih-dulu: kalau satu nama file adalah substring dari
# nama file lain (mis. "a.png" di dalam "xa.png"), mengganti yang pendek dulu
# akan merusak substitusi yang panjang.
SRCS="$(printf '%s' "$DATA_JSON" | grep -oE '"(src|logo)"[[:space:]]*:[[:space:]]*"[^"]+"' \
        | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/' | sort -u \
        | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)"

for rel in $SRCS; do
  abs="$SRC_DIR/$rel"
  [ -f "$abs" ] || { echo "error: image not found: $rel (resolved to $abs)"; exit 1; }
  uri="data:$(mime_of "$abs");base64,$(b64 "$abs")"
  # Substitusi literal lewat awk supaya karakter khusus di base64 aman.
  DATA_JSON="$(REL="$rel" URI="$uri" awk '
    BEGIN { rel = ENVIRON["REL"]; uri = ENVIRON["URI"]; q = "\"" rel "\"" }
    { n = index($0, q); while (n > 0) {
        $0 = substr($0, 1, n-1) "\"" uri "\"" substr($0, n + length(q));
        n = index($0, q) }
      print }' <<< "$DATA_JSON")"
done

# Kumpulkan style dan script.
# `cat A B` still prints A's content to stdout even when B is missing (it
# just also emits an stderr error and a non-zero exit for the missing file),
# so a `cat A B 2>/dev/null || cat A` fallback would double A into STYLES
# whenever cover.css is absent. Check for its existence explicitly instead.
if [ -f "$ROOT/assets/cover.css" ]; then
  STYLES="$(cat "$ROOT/assets/fonts.css" "$ROOT/assets/cover.css")"
else
  STYLES="$(cat "$ROOT/assets/fonts.css")"
fi
SCRIPTS="$(cat "$ROOT/assets/js/palette.js" "$ROOT/assets/js/validate.js" \
               "$ROOT/assets/js/layout.js" "$ROOT/assets/js/decor.js" \
               "$ROOT/assets/js/render.js")"

# Ambil output.dir, output.scale, dan daftar layout dari cover.js lewat sekali
# jalan headless: satu-satunya sumber kebenaran untuk render set adalah layout.js.
BROWSER="$(bash "$ROOT/scripts/find-browser.sh")" || BROWSER=""

OUT_DIR="$(printf '%s' "$DATA_JSON" | grep -oE '"dir"[[:space:]]*:[[:space:]]*"[^"]*"' \
           | sed -E 's/.*"dir"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
[ -n "$OUT_DIR" ] || OUT_DIR="cover-output"
case "$OUT_DIR" in /*) ;; *) OUT_DIR="$SRC_DIR/$OUT_DIR" ;; esac
mkdir -p "$OUT_DIR"

SCALE="$(printf '%s' "$DATA_JSON" | grep -oE '"scale"[[:space:]]*:[[:space:]]*[0-9]+' \
         | grep -oE '[0-9]+$')"
[ -n "$SCALE" ] || SCALE=2

# Halaman "planner": jalankan layout.js untuk mendapat render set.
PLAN_HTML="$OUT_DIR/_plan.html"
{
  echo '<!doctype html><meta charset="utf-8"><pre id="out"></pre><script>'
  cat "$ROOT/assets/js/validate.js" "$ROOT/assets/js/layout.js"
  echo "var D = $DATA_JSON;"
  cat <<'JS'
  try {
    var v = CoverMaker.validate.validate(D);
    document.getElementById('out').textContent =
      'SET ' + CoverMaker.layout.renderSet(v.data).join(',') +
      '\n' + v.warnings.map(function (w) { return 'WARN ' + w; }).join('\n');
  } catch (e) {
    document.getElementById('out').textContent = 'ERROR ' + e.message;
  }
JS
  echo '</script>'
} > "$PLAN_HTML"

LAYOUTS="split-right"
if [ -n "$BROWSER" ]; then
  PLAN_OUT="$("$BROWSER" --headless=new --disable-gpu --do-not-de-elevate --virtual-time-budget=4000 \
              --dump-dom "$(file_url "$PLAN_HTML")" 2>/dev/null)"
  # --dump-dom echoes the whole document, including the raw <script> source
  # that produced the result (which itself contains the literal strings
  # 'SET ', 'WARN ' and 'ERROR ' as JS string literals). Grepping the full
  # dump would double-match those tokens inside the source text as well as
  # inside the executed #out content, so cut the dump at the first <script>
  # tag and only inspect the executed part that precedes it.
  PLAN_RESULT="${PLAN_OUT%%<script>*}"
  if printf '%s' "$PLAN_RESULT" | grep -q 'ERROR '; then
    printf '%s\n' "$PLAN_RESULT" | grep -oE 'ERROR [^<]*'
    exit 1
  fi
  printf '%s\n' "$PLAN_RESULT" | grep -oE 'WARN [^<]*' || true
  LAYOUTS="$(printf '%s' "$PLAN_RESULT" | grep -oE 'SET [^<]*' | sed 's/^SET //' | tr ',' ' ')"
fi
rm -f "$PLAN_HTML"

WIDTH=$((1600 * SCALE))
HEIGHT=$((900 * SCALE))

for layout in $LAYOUTS; do
  PAGE="$OUT_DIR/render-$layout.html"
  DATA="$DATA_JSON" ST="$STYLES" SC="$SCRIPTS" LAY="$layout" SCL="$SCALE" \
  awk '
    function put(s) { printf "%s", s }
    { line = $0
      gsub(/__COVER_DATA__/, "\001DATA\001", line)
      gsub(/__STYLES__/,     "\001ST\001",   line)
      gsub(/__SCRIPTS__/,    "\001SC\001",   line)
      gsub(/__LAYOUT__/,     ENVIRON["LAY"], line)
      gsub(/__SCALE__/,      ENVIRON["SCL"], line)
      n = split(line, parts, "\001")
      for (i = 1; i <= n; i++) {
        if (parts[i] == "DATA")    put(ENVIRON["DATA"])
        else if (parts[i] == "ST") put(ENVIRON["ST"])
        else if (parts[i] == "SC") put(ENVIRON["SC"])
        else put(parts[i])
      }
      put("\n") }
  ' "$ROOT/assets/template.html" > "$PAGE"
  echo "html: $PAGE"

  if [ -z "$BROWSER" ]; then continue; fi

  "$BROWSER" --headless=new --disable-gpu --do-not-de-elevate --hide-scrollbars \
    --force-device-scale-factor=1 --virtual-time-budget=8000 \
    --window-size="$WIDTH,$HEIGHT" \
    --screenshot="$OUT_DIR/$layout.png" "$(file_url "$PAGE")" >/dev/null 2>&1
  echo "png:  $OUT_DIR/$layout.png"
done

if [ -z "$BROWSER" ]; then
  echo "warn: no Chromium-based browser found. The HTML pages above are fully"
  echo "warn: self-contained - open one in any browser and screenshot it manually."
  exit 2
fi
