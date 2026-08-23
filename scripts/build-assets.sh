#!/usr/bin/env bash
# Generator: assets/fonts.css dan assets/js/decor.js.
# Dijalankan manual saat font atau SVG sumber berubah. Bukan bagian dari alur render.
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
FONTS="$HERE/assets/fonts"
DECOR="$HERE/assets/decor"

b64() {
  if base64 --help 2>&1 | grep -q -- '-w'; then base64 -w0 "$1"; else base64 -i "$1"; fi
}

# --- fonts.css ---
{
  echo "/* GENERATED oleh scripts/build-assets.sh. Jangan diedit tangan. */"
  emit_face() {
    printf '@font-face{font-family:"%s";font-style:normal;font-weight:%s;font-display:block;src:url(data:font/woff2;base64,%s) format("woff2");}\n' \
      "$1" "$2" "$(b64 "$FONTS/$3")"
  }
  emit_face "Outfit" 700 "Outfit-Bold.woff2"
  emit_face "Outfit" 600 "Outfit-SemiBold.woff2"
  emit_face "Inter"  400 "Inter-Regular.woff2"
  emit_face "Inter"  500 "Inter-Medium.woff2"
} > "$HERE/assets/fonts.css"

# --- js/decor.js ---
# Beri prefix unik pada id/url(#..) supaya beberapa SVG bisa inline bersamaan.
emit_shape() {
  local key="$1" file="$2"
  local svg
  svg="$(tr -d '\n' < "$DECOR/$file")"
  # Strip xmlns: unnecessary for inline SVG parsed as HTML foreign content
  # (the HTML5 parser auto-detects <svg> and switches namespace on its own),
  # and its "http://www.w3.org/2000/svg" value would otherwise trip the
  # no-external-reference check below.
  svg="$(printf '%s' "$svg" | sed -e "s/id=\"/id=\"cm-${key}-/g" -e "s/url(#/url(#cm-${key}-/g" -e 's/ xmlns="http:\/\/www\.w3\.org\/2000\/svg"//g')"
  printf '    %s: %s,\n' "$key" "$(printf '%s' "$svg" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g" -e "s/^/'/" -e "s/$/'/")"
}

{
  echo "// GENERATED oleh scripts/build-assets.sh. Jangan diedit tangan."
  echo "(function (global) {"
  echo "  var NS = global.CoverMaker = global.CoverMaker || {};"
  echo "  var SHAPES = {"
  emit_shape brush "brush-01.svg"
  emit_shape blob  "blob-01.svg"
  emit_shape dots  "dots.svg"
  emit_shape grid  "grid.svg"
  echo "  };"
  cat <<'JS'
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
JS
} > "$HERE/assets/js/decor.js"

echo "generated: assets/fonts.css, assets/js/decor.js"
