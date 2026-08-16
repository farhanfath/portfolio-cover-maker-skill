# project-cover-maker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun skill portabel yang membuat 4 varian cover portfolio (PNG 3200×1800) untuk project mobile app, dari screenshot asli milik user.

**Architecture:** Renderer berupa satu halaman HTML yang di-screenshot oleh headless Chrome. Render script membangun halaman **self-contained penuh** (gambar base64, font base64, SVG inline, data JSON di-inject) supaya tidak ada resource eksternal — syarat mutlak agar `canvas.getImageData()` tidak kena tainting saat mengekstrak palet. Semua penilaian visual dikerjakan agent LLM lewat file `cover.json`; renderer murni deterministik.

**Tech Stack:** HTML + CSS (OKLCH, aspect-ratio, zoom) + JavaScript klasik (bukan ES module) + shell script (bash & PowerShell) + headless Chrome. **Nol dependency yang perlu dipasang.**

**Spec:** `docs/superpowers/specs/2026-08-16-project-cover-maker-design.md`

## Global Constraints

Berlaku untuk **setiap** task di bawah ini.

- **Tanpa package manager.** Dilarang `npm install`, `pip install`, `cargo add`, atau apapun yang mengunduh dependency. Hanya boleh memakai: filesystem, shell bawaan OS, dan browser Chromium-based yang sudah terpasang. (Spec §4.2)
- **Tanpa akses jaringan saat render.** Tidak boleh ada `<link>`, `@import`, `url()`, `fetch()`, atau `src` yang menunjuk ke `http://` / `https://`. (Spec §4.2)
- **Halaman render nol resource eksternal.** Semua gambar, font, dan SVG masuk sebagai `data:` URI atau markup inline. Tidak boleh ada `file://` di halaman hasil. (Spec §4.1.1, invarian §12.4)
- **JavaScript klasik, bukan ES module.** Dilarang `import` / `export` / `type="module"` — Chrome memblokir ES module dari origin `file://`, sehingga `tests/test.html` tidak akan bisa memuatnya. Semua modul menempel ke satu global `window.CoverMaker`.
- **Kanvas logis 1600×900**, dirender pada `output.scale` (default 2) sehingga PNG akhirnya 3200×1800. (Spec §8.1)
- **Semua ukuran layout relatif terhadap lebar HP atau lebar kanvas**, bukan angka absolut yang tidak berskala. (Spec §8.1)
- **Palet diturunkan dari satu angka hue memakai OKLCH**, tidak pernah disampel langsung dari screenshot. (Spec §8.5, invarian §12.5)
- **Font:** Outfit (Bold, SemiBold) untuk wordmark, Inter (Regular, Medium) untuk tagline/badge. Keduanya OFL. (Spec §8.7)
- **Hue fallback saat app grayscale: 215°.** (Spec §8.5)
- **Konstanta palet awal** (Spec §8.5) — nilai usulan, **Test #1 adalah sumber kebenarannya**; kalau ada hue yang gagal ≥4.5:1, konstanta ini yang disesuaikan, bukan ambang test-nya:
  ```
  --base      = oklch(0.38 0.09 H)
  --accent    = oklch(0.55 0.13 H)
  --ink       = oklch(0.30 0.05 H)
  --surface-a = oklch(0.97 0.02 H)
  --surface-b = oklch(0.86 0.06 H)
  ```
- **Commit di tiap akhir task.** Pesan commit bahasa Inggris, imperatif, prefix `feat:` / `test:` / `docs:` / `chore:`.

---

## File Structure

| File | Tanggung jawab |
|---|---|
| `SKILL.md` | Alur kerja agent + aturan keputusan. ≤200 baris. |
| `assets/template.html` | Kerangka halaman + placeholder `__STYLES__`, `__SCRIPTS__`, `__COVER_DATA__`, `__LAYOUT__`, `__SCALE__`. |
| `assets/cover.css` | Design token, kanvas, device frame, 5 arketipe layout. Ditulis tangan. |
| `assets/fonts.css` | **Generated.** Hanya blok `@font-face` berisi woff2 base64. Jangan diedit tangan. |
| `assets/fonts/*.woff2` | Sumber font, dipakai untuk men-generate `fonts.css`. |
| `assets/decor/*.svg` | Sumber SVG dekorasi, dipakai untuk men-generate `assets/js/decor.js`. |
| `assets/js/validate.js` | Validasi `cover.json` (spec §7.2). |
| `assets/js/palette.js` | Ekstraksi hue, penurunan palet OKLCH, konversi OKLCH→sRGB, kontras WCAG. |
| `assets/js/layout.js` | Kelayakan arketipe, pilihan `auto`, penyusunan render set. |
| `assets/js/decor.js` | **Generated.** Markup SVG inline sebagai string. |
| `assets/js/render.js` | Perakitan DOM, pemasangan palet, fitting wordmark, deteksi logo berlatar terang. |
| `scripts/find-browser.sh` / `.ps1` | Penemuan binary browser. Dipakai render script **dan** test runner. |
| `scripts/render.sh` / `.ps1` | Bangun halaman self-contained, panggil browser, tulis PNG. |
| `scripts/build-assets.sh` / `.ps1` | Generator `fonts.css` dan `js/decor.js` dari folder sumber. |
| `tests/assert.js` | Runner assertion mini yang menulis `PASS`/`FAIL` ke DOM. |
| `tests/test.html` | Memuat modul + seluruh unit test (Test #1–#4). |
| `tests/run.sh` / `.ps1` | Jalankan test.html headless, jalankan Test #5 & #6, grep `FAIL`. |
| `tests/fixture/` | 3 screenshot dummy + `cover.json`. |
| `tests/make-fixture.sh` / `.ps1` | Generator screenshot dummy memakai Chrome. |
| `references/layouts.md` | Anatomi tiap arketipe. |
| `references/capture-adb.md` | Protokol capture lewat adb. |

---

## Task 1: Penemuan browser + harness test

**Files:**
- Create: `scripts/find-browser.sh`
- Create: `scripts/find-browser.ps1`
- Create: `tests/assert.js`
- Create: `tests/test.html`
- Create: `tests/run.sh`
- Create: `tests/run.ps1`

**Interfaces:**
- Consumes: —
- Produces:
  - `find-browser.sh` mencetak path browser ke stdout, exit 0; kalau tidak ketemu exit 1 tanpa output.
  - `find-browser.ps1` mencetak path browser, `exit 0`; kalau tidak ketemu `exit 1`.
  - Global JS `Assert.eq(actual, expected, label)`, `Assert.ok(cond, label)`, `Assert.close(actual, expected, tol, label)`, `Assert.throws(fn, substr, label)`, `Assert.done()`.
  - `tests/run.sh` dan `tests/run.ps1` exit 0 kalau semua PASS, exit 1 kalau ada `FAIL`.

- [ ] **Step 1: Tulis `scripts/find-browser.sh`**

```bash
#!/usr/bin/env bash
# Mencetak path binary browser Chromium-based ke stdout. Exit 1 kalau tidak ada.
set -u

for c in google-chrome-stable google-chrome chromium chromium-browser chrome msedge; do
  if command -v "$c" >/dev/null 2>&1; then command -v "$c"; exit 0; fi
done

CANDIDATES=(
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  "/Applications/Chromium.app/Contents/MacOS/Chromium"
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
  "/usr/bin/google-chrome"
  "/usr/bin/chromium"
  "/usr/bin/chromium-browser"
  "/opt/google/chrome/chrome"
  "/snap/bin/chromium"
  "/c/Program Files/Google/Chrome/Application/chrome.exe"
  "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"
  "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
  "/c/Program Files/Microsoft/Edge/Application/msedge.exe"
)
for p in "${CANDIDATES[@]}"; do
  if [ -x "$p" ]; then printf '%s\n' "$p"; exit 0; fi
done
exit 1
```

- [ ] **Step 2: Tulis `scripts/find-browser.ps1`**

```powershell
# Mencetak path binary browser Chromium-based. exit 1 kalau tidak ada.
$ErrorActionPreference = 'SilentlyContinue'

foreach ($n in @('chrome','msedge','chromium')) {
  $c = (Get-Command $n).Source
  if ($c) { Write-Output $c; exit 0 }
}

$candidates = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
)
foreach ($p in $candidates) {
  if (Test-Path $p) { Write-Output $p; exit 0 }
}
exit 1
```

- [ ] **Step 3: Tulis `tests/assert.js`**

```javascript
// Runner assertion mini. Menulis baris PASS/FAIL ke #out supaya bisa dibaca --dump-dom.
(function (global) {
  var results = [];
  function record(pass, label, detail) {
    results.push((pass ? 'PASS' : 'FAIL') + ' :: ' + label + (detail ? ' :: ' + detail : ''));
  }
  var Assert = {
    eq: function (actual, expected, label) {
      var a = JSON.stringify(actual), e = JSON.stringify(expected);
      record(a === e, label, a === e ? '' : 'got ' + a + ' want ' + e);
    },
    ok: function (cond, label) { record(!!cond, label, cond ? '' : 'expected truthy'); },
    close: function (actual, expected, tol, label) {
      var pass = Math.abs(actual - expected) <= tol;
      record(pass, label, pass ? '' : 'got ' + actual + ' want ' + expected + ' +/-' + tol);
    },
    throws: function (fn, substr, label) {
      try { fn(); record(false, label, 'no error thrown'); }
      catch (e) {
        var msg = String(e && e.message || e);
        record(msg.indexOf(substr) !== -1, label,
               msg.indexOf(substr) !== -1 ? '' : 'message "' + msg + '" lacks "' + substr + '"');
      }
    },
    done: function () {
      var fails = results.filter(function (r) { return r.indexOf('FAIL') === 0; }).length;
      var el = document.getElementById('out');
      el.textContent = results.join('\n') + '\nTOTAL ' + results.length + ' FAILED ' + fails;
    }
  };
  global.Assert = Assert;
})(window);
```

- [ ] **Step 4: Tulis `tests/test.html` (baru berisi satu self-test)**

```html
<!doctype html>
<meta charset="utf-8">
<title>cover-maker tests</title>
<pre id="out"></pre>
<script src="assert.js"></script>
<script>
Assert.eq(1 + 1, 2, 'harness: sanity');
Assert.done();
</script>
```

- [ ] **Step 5: Tulis `tests/run.sh`**

```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BROWSER="$("$HERE/../scripts/find-browser.sh")" || { echo "FAIL :: no Chromium-based browser found"; exit 1; }

OUT="$("$BROWSER" --headless=new --disable-gpu --virtual-time-budget=5000 \
       --dump-dom "file://$HERE/test.html" 2>/dev/null)"

echo "$OUT" | grep -oE '(PASS|FAIL|TOTAL) [^<]*' || true
if echo "$OUT" | grep -q 'FAIL ::'; then echo "--- unit tests FAILED ---"; exit 1; fi
echo "--- unit tests passed ---"
```

- [ ] **Step 6: Tulis `tests/run.ps1`**

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$browser = & "$here\..\scripts\find-browser.ps1"
if (-not $browser) { Write-Output "FAIL :: no Chromium-based browser found"; exit 1 }

$out = & $browser --headless=new --disable-gpu --virtual-time-budget=5000 --dump-dom "file:///$($here -replace '\\','/')/test.html"
$text = $out -join "`n"
[regex]::Matches($text, '(PASS|FAIL|TOTAL) [^<]*') | ForEach-Object { Write-Output $_.Value }
if ($text -match 'FAIL ::') { Write-Output "--- unit tests FAILED ---"; exit 1 }
Write-Output "--- unit tests passed ---"
```

- [ ] **Step 7: Jalankan harness, pastikan lulus**

Run: `bash tests/run.sh` (atau `powershell -File tests/run.ps1` di Windows)
Expected: memuat baris `PASS :: harness: sanity`, `TOTAL 1 FAILED 0`, dan `--- unit tests passed ---`, exit 0.

- [ ] **Step 8: Buktikan harness bisa gagal**

Ubah sementara Step 4 jadi `Assert.eq(1 + 1, 3, 'harness: sanity');`, jalankan lagi.
Expected: `FAIL :: harness: sanity :: got 2 want 3` dan exit 1. **Kembalikan ke `2` setelah terbukti.**

Ini penting: harness yang tidak pernah bisa merah adalah harness yang tidak berguna.

- [ ] **Step 9: Commit**

```bash
chmod +x scripts/find-browser.sh tests/run.sh
git add scripts/find-browser.sh scripts/find-browser.ps1 tests/assert.js tests/test.html tests/run.sh tests/run.ps1
git commit -m "test: add browser discovery and zero-dependency test harness"
```

---

## Task 2: Modul palet — ekstraksi hue, penurunan OKLCH, invarian kontras

Ini task paling berisiko, dikerjakan lebih awal supaya konstanta palet bisa disetel sebelum apapun bergantung padanya.

**Files:**
- Create: `assets/js/palette.js`
- Modify: `tests/test.html` (tambah `<script src="../assets/js/palette.js">` dan blok Test #1 & #2)

**Interfaces:**
- Consumes: `Assert` dari Task 1.
- Produces — semuanya di `window.CoverMaker.palette`:
  - `rgbToHsl(r, g, b) -> {h: 0..360, s: 0..1, l: 0..1}`
  - `extractHue(imageData) -> {hue: number, fallback: boolean}`
  - `derive(hue) -> {base, accent, ink, surfaceA, surfaceB}` — tiap nilai `{L, C, H}`
  - `oklchToLinearRgb(L, C, H) -> [r, g, b]` linear, **belum di-clamp**
  - `luminance(L, C, H) -> number` (WCAG relative luminance, clamp ke [0,1])
  - `contrast(colorA, colorB) -> number` — argumen berupa objek `{L, C, H}`
  - `toCss(color) -> string` → `"oklch(0.38 0.09 160)"`

- [ ] **Step 1: Tulis test yang gagal — Test #1 (invarian kontras) & Test #2 (ekstraksi hue)**

Tambahkan ke `tests/test.html`, di antara `<script src="assert.js">` dan blok `Assert.done()`:

```html
<script src="../assets/js/palette.js"></script>
<canvas id="probe" width="100" height="200" style="display:none"></canvas>
<script>
var P = CoverMaker.palette;

// --- Test #1: invarian kontras di seluruh 360 hue ---
(function () {
  var worstInk = Infinity, worstBase = Infinity, worstHueInk = -1, worstHueBase = -1;
  for (var h = 0; h < 360; h++) {
    var p = P.derive(h);
    var cInk  = P.contrast(p.ink,  p.surfaceB);
    var cBase = P.contrast(p.base, p.surfaceB);
    if (cInk  < worstInk)  { worstInk  = cInk;  worstHueInk  = h; }
    if (cBase < worstBase) { worstBase = cBase; worstHueBase = h; }
  }
  Assert.ok(worstInk  >= 4.5, 'palette: ink on surface-b >= 4.5:1 for all hues (worst '
            + worstInk.toFixed(2) + ' at H=' + worstHueInk + ')');
  Assert.ok(worstBase >= 4.5, 'palette: base on surface-b >= 4.5:1 for all hues (worst '
            + worstBase.toFixed(2) + ' at H=' + worstHueBase + ')');
})();

// --- Test #2: ekstraksi hue ---
function makeImageData(spec) {
  // spec: array of {frac, rgb}
  var c = document.getElementById('probe');
  var ctx = c.getContext('2d');
  var total = c.width * c.height;
  var img = ctx.createImageData(c.width, c.height);
  var i = 0;
  spec.forEach(function (s) {
    var n = Math.round(total * s.frac);
    for (var k = 0; k < n && i < total; k++, i++) {
      img.data[i * 4] = s.rgb[0]; img.data[i * 4 + 1] = s.rgb[1];
      img.data[i * 4 + 2] = s.rgb[2]; img.data[i * 4 + 3] = 255;
    }
  });
  for (; i < total; i++) { img.data[i * 4 + 3] = 255; } // sisa: hitam
  return img;
}

(function () {
  // 60% putih (chrome UI) + 25% teal H=160 + 15% hitam (teks) -> harus ketemu ~160
  var teal = P.oklchToLinearRgb(0.55, 0.13, 160).map(function (v) {
    v = Math.max(0, Math.min(1, v));
    return Math.round(255 * (v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055));
  });
  var got = P.extractHue(makeImageData([
    { frac: 0.60, rgb: [255, 255, 255] },
    { frac: 0.25, rgb: teal },
    { frac: 0.15, rgb: [0, 0, 0] }
  ]));
  Assert.ok(!got.fallback, 'palette: brand hue detected, not fallback');
  Assert.close(got.hue, 160, 15, 'palette: extracted hue within 15deg of 160');
})();

(function () {
  // grayscale penuh -> fallback 215
  var got = P.extractHue(makeImageData([
    { frac: 0.5, rgb: [255, 255, 255] },
    { frac: 0.3, rgb: [128, 128, 128] },
    { frac: 0.2, rgb: [20, 20, 20] }
  ]));
  Assert.ok(got.fallback, 'palette: grayscale image reports fallback');
  Assert.eq(got.hue, 215, 'palette: grayscale fallback hue is 215');
})();
</script>
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `bash tests/run.sh`
Expected: gagal karena `CoverMaker is not defined` — file `palette.js` belum ada. Exit 1.

- [ ] **Step 3: Tulis `assets/js/palette.js`**

```javascript
// Ekstraksi hue brand + penurunan palet OKLCH.
// Klasik, bukan ES module: Chrome memblokir modul dari origin file://.
(function (global) {
  var NS = global.CoverMaker = global.CoverMaker || {};

  var FALLBACK_HUE = 215;
  var BIN_COUNT = 24;          // 24 bin @ 15 derajat
  var MIN_KEPT_RATIO = 0.02;   // <2% pixel brand -> anggap grayscale

  // Konstanta palet. Sumber kebenarannya Test #1, bukan komentar ini.
  var RECIPE = {
    base:     { L: 0.38, C: 0.09 },
    accent:   { L: 0.55, C: 0.13 },
    ink:      { L: 0.30, C: 0.05 },
    surfaceA: { L: 0.97, C: 0.02 },
    surfaceB: { L: 0.86, C: 0.06 }
  };

  function rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    var max = Math.max(r, g, b), min = Math.min(r, g, b);
    var l = (max + min) / 2, h = 0, s = 0, d = max - min;
    if (d !== 0) {
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      if (max === r)      h = ((g - b) / d + (g < b ? 6 : 0));
      else if (max === g) h = ((b - r) / d + 2);
      else                h = ((r - g) / d + 4);
      h *= 60;
    }
    return { h: h, s: s, l: l };
  }

  function extractHue(imageData) {
    var d = imageData.data;
    var total = d.length / 4;
    var bins = new Float64Array(BIN_COUNT);
    var kept = 0;
    for (var i = 0; i < d.length; i += 4) {
      var hsl = rgbToHsl(d[i], d[i + 1], d[i + 2]);
      // Buang chrome UI: hampir putih, hampir hitam, atau pucat.
      if (hsl.l > 0.92 || hsl.l < 0.08 || hsl.s < 0.18) continue;
      kept++;
      bins[Math.floor(hsl.h / 15) % BIN_COUNT] += hsl.s; // bobot = saturasi
    }
    if (kept / total < MIN_KEPT_RATIO) return { hue: FALLBACK_HUE, fallback: true };
    var best = 0;
    for (var k = 1; k < BIN_COUNT; k++) if (bins[k] > bins[best]) best = k;
    return { hue: best * 15 + 7.5, fallback: false };
  }

  function derive(hue) {
    var out = {};
    for (var key in RECIPE) {
      out[key] = { L: RECIPE[key].L, C: RECIPE[key].C, H: hue };
    }
    return out;
  }

  // OKLCH -> OKLab -> LMS -> linear sRGB. Hasil bisa di luar gamut.
  function oklchToLinearRgb(L, C, Hdeg) {
    var h = Hdeg * Math.PI / 180;
    var a = C * Math.cos(h), bb = C * Math.sin(h);
    var l_ = L + 0.3963377774 * a + 0.2158037573 * bb;
    var m_ = L - 0.1055613458 * a - 0.0638541728 * bb;
    var s_ = L - 0.0894841775 * a - 1.2914855480 * bb;
    var l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_;
    return [
       4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    ];
  }

  // Luminance WCAG. Nilai di luar gamut di-clamp naif; Chrome memakai gamut
  // mapping yang sedikit berbeda, jadi angka ini pendekatan. Mitigasinya:
  // Test #1 menuntut margin di atas ambang, bukan pas di ambang.
  function luminance(L, C, H) {
    var lin = oklchToLinearRgb(L, C, H);
    var r = Math.max(0, Math.min(1, lin[0]));
    var g = Math.max(0, Math.min(1, lin[1]));
    var b = Math.max(0, Math.min(1, lin[2]));
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  function contrast(a, b) {
    var la = luminance(a.L, a.C, a.H);
    var lb = luminance(b.L, b.C, b.H);
    var hi = Math.max(la, lb), lo = Math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  function toCss(c) {
    return 'oklch(' + c.L + ' ' + c.C + ' ' + c.H.toFixed(1) + ')';
  }

  NS.palette = {
    rgbToHsl: rgbToHsl,
    extractHue: extractHue,
    derive: derive,
    oklchToLinearRgb: oklchToLinearRgb,
    luminance: luminance,
    contrast: contrast,
    toCss: toCss,
    FALLBACK_HUE: FALLBACK_HUE,
    RECIPE: RECIPE
  };
})(window);
```

- [ ] **Step 4: Jalankan test**

Run: `bash tests/run.sh`
Expected: keenam assertion PASS.

**Kalau Test #1 gagal** (ada hue dengan kontras <4.5): jangan turunkan ambangnya. Setel `RECIPE` — turunkan `L` pada `base`/`ink`, atau naikkan `L` pada `surfaceB` — 0.02 per langkah, jalankan ulang sampai lulus. Pesan assertion sudah menyebutkan hue terburuknya, pakai itu sebagai panduan. Setelah lulus, **salin nilai final ke spec §8.5** supaya dokumen dan kode tidak berbeda.

- [ ] **Step 5: Commit**

```bash
git add assets/js/palette.js tests/test.html
git commit -m "feat: derive OKLCH palette from dominant hue with contrast invariant"
```

---

## Task 3: Validasi kontrak `cover.json`

**Files:**
- Create: `assets/js/validate.js`
- Modify: `tests/test.html`

**Interfaces:**
- Consumes: `Assert`.
- Produces — `window.CoverMaker.validate`:
  - `validate(data) -> {data: normalized, warnings: string[]}` — melempar `Error` dengan pesan yang menyebut nama field pada pelanggaran yang menolak.

- [ ] **Step 1: Tulis test yang gagal — Test #3**

Tambahkan ke `tests/test.html`:

```html
<script src="../assets/js/validate.js"></script>
<script>
var V = CoverMaker.validate.validate;

function good() {
  return {
    project: { name: 'TripMate', tagline: 'Your smart travel assistant' },
    screens: [
      { src: 'a.png', role: 'hero' },
      { src: 'b.png', role: 'support' },
      { src: 'c.png', role: 'support' }
    ]
  };
}

Assert.ok(V(good()).warnings.length === 0, 'validate: valid input has no warnings');

// Default terisi
(function () {
  var r = V(good());
  Assert.eq(r.data.layout, 'auto', 'validate: layout defaults to auto');
  Assert.eq(r.data.palette.mode, 'auto', 'validate: palette.mode defaults to auto');
  Assert.eq(r.data.decor, 'auto', 'validate: decor defaults to auto');
  Assert.eq(r.data.output.dir, 'cover-output', 'validate: output.dir default');
  Assert.eq(r.data.output.scale, 2, 'validate: output.scale default');
  Assert.eq(r.data.badges, [], 'validate: badges defaults to empty');
})();

// name >16 -> warning, bukan tolak
(function () {
  var d = good(); d.project.name = 'SuperLongProjectName';
  var r = V(d);
  Assert.ok(r.warnings.join(' ').indexOf('name') !== -1, 'validate: long name warns about name');
  Assert.eq(r.data.project.name, 'SuperLongProjectName', 'validate: long name is kept as-is');
})();

// tagline >64 -> tolak
(function () {
  var d = good(); d.project.tagline = 'x'.repeat(65);
  Assert.throws(function () { V(d); }, 'tagline', 'validate: tagline over 64 is rejected');
})();

// screens kosong / >6 -> tolak
Assert.throws(function () { var d = good(); d.screens = []; V(d); },
              'screens', 'validate: empty screens rejected');
Assert.throws(function () {
  var d = good();
  d.screens = [{ src: 'a.png', role: 'hero' }];
  for (var i = 0; i < 6; i++) d.screens.push({ src: i + '.png', role: 'support' });
  V(d);
}, 'screens', 'validate: more than 6 screens rejected');

// hero bukan tepat satu -> tolak, sebut jumlahnya
Assert.throws(function () {
  var d = good(); d.screens[1].role = 'hero'; V(d);
}, '2', 'validate: two heroes rejected and count reported');
Assert.throws(function () {
  var d = good(); d.screens[0].role = 'support'; V(d);
}, '0', 'validate: zero heroes rejected and count reported');

// src kosong -> tolak, sebut indeksnya
Assert.throws(function () { var d = good(); d.screens[1].src = ''; V(d); },
              'screens[1]', 'validate: missing src names the offending index');

// badges >4 -> dipotong + warning
(function () {
  var d = good();
  d.badges = [1,2,3,4,5].map(function (i) { return { src: i + '.png', label: 'b' + i }; });
  var r = V(d);
  Assert.eq(r.data.badges.length, 4, 'validate: badges truncated to 4');
  Assert.ok(r.warnings.join(' ').indexOf('badges') !== -1, 'validate: badge truncation warns');
})();

// meta >12 -> dipotong + warning
(function () {
  var d = good(); d.meta = 'ABCDEFGHIJKLMNOP';
  var r = V(d);
  Assert.eq(r.data.meta.length, 12, 'validate: meta truncated to 12');
  Assert.ok(r.warnings.join(' ').indexOf('meta') !== -1, 'validate: meta truncation warns');
})();

// palette manual tanpa warna lengkap -> tolak, sebut field yang kurang
Assert.throws(function () {
  var d = good(); d.palette = { mode: 'manual', base: '#123456' }; V(d);
}, 'accent', 'validate: incomplete manual palette names the missing field');

// layout tidak dikenal -> tolak
Assert.throws(function () { var d = good(); d.layout = 'diagonal'; V(d); },
              'layout', 'validate: unknown layout rejected');
</script>
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `bash tests/run.sh`
Expected: gagal — `CoverMaker.validate is undefined`.

- [ ] **Step 3: Tulis `assets/js/validate.js`**

```javascript
(function (global) {
  var NS = global.CoverMaker = global.CoverMaker || {};

  var LAYOUTS = ['auto', 'split-right', 'split-left', 'centered', 'scatter', 'solo'];
  var DECORS  = ['auto', 'brush', 'blob', 'dots', 'grid', 'none'];
  var MANUAL_KEYS = ['base', 'accent', 'ink', 'surfaceA', 'surfaceB'];

  function fail(msg) { throw new Error(msg); }

  function validate(input) {
    var warnings = [];
    if (!input || typeof input !== 'object') fail('cover.json: root must be an object');

    var p = input.project;
    if (!p || typeof p !== 'object') fail('cover.json: "project" is required');
    if (typeof p.name !== 'string' || p.name.length < 1) fail('cover.json: "project.name" is required');
    if (p.name.length > 16) {
      warnings.push('project.name is ' + p.name.length + ' chars (>16); wordmark will shrink');
    }
    if (typeof p.tagline !== 'string' || p.tagline.length < 1) fail('cover.json: "project.tagline" is required');
    if (p.tagline.length > 64) {
      fail('cover.json: "project.tagline" is ' + p.tagline.length + ' chars, max 64 (two lines is a hard limit)');
    }

    var screens = input.screens;
    if (!Array.isArray(screens) || screens.length < 1 || screens.length > 6) {
      fail('cover.json: "screens" must hold 1-6 items, got ' + (Array.isArray(screens) ? screens.length : 0));
    }
    var heroes = 0;
    screens.forEach(function (s, i) {
      if (!s || typeof s.src !== 'string' || !s.src) fail('cover.json: "screens[' + i + '].src" is missing');
      if (s.role !== 'hero' && s.role !== 'support') {
        fail('cover.json: "screens[' + i + '].role" must be "hero" or "support"');
      }
      if (s.role === 'hero') heroes++;
    });
    if (heroes !== 1) fail('cover.json: exactly one screen must have role "hero", found ' + heroes);

    var badges = Array.isArray(input.badges) ? input.badges.slice() : [];
    badges.forEach(function (b, i) {
      if (!b || typeof b.src !== 'string' || !b.src) fail('cover.json: "badges[' + i + '].src" is missing');
    });
    if (badges.length > 4) {
      warnings.push('badges has ' + badges.length + ' items; only the first 4 are used');
      badges = badges.slice(0, 4);
    }

    var meta = typeof input.meta === 'string' ? input.meta : null;
    if (meta && meta.length > 12) {
      warnings.push('meta is ' + meta.length + ' chars (>12) and was truncated');
      meta = meta.slice(0, 12);
    }

    var layout = input.layout || 'auto';
    if (LAYOUTS.indexOf(layout) === -1) {
      fail('cover.json: "layout" must be one of ' + LAYOUTS.join(', ') + ', got "' + layout + '"');
    }

    var decor = input.decor || 'auto';
    if (DECORS.indexOf(decor) === -1) {
      fail('cover.json: "decor" must be one of ' + DECORS.join(', ') + ', got "' + decor + '"');
    }

    var palette = input.palette || { mode: 'auto' };
    if (palette.mode !== 'auto' && palette.mode !== 'manual') {
      fail('cover.json: "palette.mode" must be "auto" or "manual"');
    }
    if (palette.mode === 'manual') {
      MANUAL_KEYS.forEach(function (k) {
        if (typeof palette[k] !== 'string' || !palette[k]) {
          fail('cover.json: "palette.' + k + '" is required when palette.mode is "manual"');
        }
      });
    }

    var output = input.output || {};
    var scale = output.scale === 1 ? 1 : 2;
    var dir = typeof output.dir === 'string' && output.dir ? output.dir : 'cover-output';

    return {
      warnings: warnings,
      data: {
        project: { name: p.name, tagline: p.tagline, logo: p.logo || null },
        screens: screens,
        badges: badges,
        meta: meta,
        layout: layout,
        decor: decor,
        palette: palette,
        output: { dir: dir, scale: scale }
      }
    };
  }

  NS.validate = { validate: validate, LAYOUTS: LAYOUTS, DECORS: DECORS };
})(window);
```

**Catatan:** keberadaan file di `screens[].src` divalidasi oleh render script (Task 7), bukan di sini — `cover.js` berjalan di browser dan tidak punya akses filesystem.

- [ ] **Step 4: Jalankan test**

Run: `bash tests/run.sh`
Expected: seluruh assertion validate PASS, `FAILED 0`.

- [ ] **Step 5: Commit**

```bash
git add assets/js/validate.js tests/test.html
git commit -m "feat: validate cover.json contract with field-specific messages"
```

---

## Task 4: Pemilihan layout & penyusunan render set

**Files:**
- Create: `assets/js/layout.js`
- Modify: `tests/test.html`

**Interfaces:**
- Consumes: `Assert`, output ternormalisasi dari `CoverMaker.validate.validate`.
- Produces — `window.CoverMaker.layout`:
  - `ELIGIBILITY` — objek `{arketipe: minScreens}`
  - `PRIORITY` — array urutan prioritas
  - `eligible(n) -> string[]`
  - `autoLayout(data) -> string`
  - `renderSet(data) -> string[]` (maksimum 4, elemen pertama = hasil `autoLayout`)

- [ ] **Step 1: Tulis test yang gagal — Test #4**

Tambahkan ke `tests/test.html`:

```html
<script src="../assets/js/layout.js"></script>
<script>
var L = CoverMaker.layout;

function mk(n, opts) {
  opts = opts || {};
  var screens = [];
  for (var i = 0; i < n; i++) screens.push({ src: i + '.png', role: i === 0 ? 'hero' : 'support' });
  return {
    project: {
      name: opts.name || 'TripMate',
      tagline: opts.tagline || 'Your smart travel assistant',
      logo: opts.logo || null
    },
    screens: screens,
    layout: opts.layout || 'auto'
  };
}

Assert.eq(L.eligible(1), ['solo'], 'layout: 1 screen only allows solo');
Assert.eq(L.eligible(2), ['split-right', 'split-left', 'solo'], 'layout: 2 screens allow three archetypes');
Assert.eq(L.eligible(3), ['split-right', 'split-left', 'centered', 'solo'], 'layout: 3 screens exclude scatter');
Assert.eq(L.eligible(5), ['split-right', 'split-left', 'centered', 'scatter', 'solo'], 'layout: 5 screens allow all');

Assert.eq(L.autoLayout(mk(1)), 'solo', 'layout: auto picks solo for 1 screen');
Assert.eq(L.autoLayout(mk(2)), 'solo', 'layout: auto picks solo for 2 screens');
Assert.eq(L.autoLayout(mk(6)), 'scatter', 'layout: auto picks scatter for 6 screens');
Assert.eq(L.autoLayout(mk(3, { logo: 'l.png', name: 'Glowfy' })), 'centered',
          'layout: auto picks centered when logo present and name short');
Assert.eq(L.autoLayout(mk(3, { name: 'Jamali Parenting' })), 'split-left',
          'layout: auto picks split-left for long name');
Assert.eq(L.autoLayout(mk(3, { tagline: 'x'.repeat(46) })), 'split-left',
          'layout: auto picks split-left for long tagline');
Assert.eq(L.autoLayout(mk(3)), 'split-right', 'layout: auto falls through to split-right');

Assert.eq(L.renderSet(mk(1)), ['solo'], 'layout: render set for 1 screen is solo alone');
Assert.eq(L.renderSet(mk(2)), ['solo', 'split-right', 'split-left'],
          'layout: render set for 2 screens holds three, auto first');
Assert.eq(L.renderSet(mk(3)), ['split-right', 'split-left', 'centered', 'solo'],
          'layout: render set for 3 screens holds four without scatter');
Assert.eq(L.renderSet(mk(6)), ['scatter', 'split-right', 'split-left', 'centered'],
          'layout: render set for 6 screens holds four with scatter first');
Assert.eq(L.renderSet(mk(6, { layout: 'centered' })), ['centered'],
          'layout: explicit layout renders exactly one');
</script>
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `bash tests/run.sh`
Expected: gagal — `CoverMaker.layout is undefined`.

- [ ] **Step 3: Tulis `assets/js/layout.js`**

```javascript
(function (global) {
  var NS = global.CoverMaker = global.CoverMaker || {};

  var ELIGIBILITY = {
    'solo': 1,
    'split-right': 2,
    'split-left': 2,
    'centered': 3,
    'scatter': 5
  };

  // Urutan pengisian render set setelah pilihan auto.
  var PRIORITY = ['split-right', 'split-left', 'centered', 'scatter', 'solo'];

  var MAX_SET = 4;

  function eligible(n) {
    return PRIORITY.filter(function (a) { return n >= ELIGIBILITY[a]; });
  }

  function autoLayout(data) {
    var n = data.screens.length;
    var name = data.project.name || '';
    var tagline = data.project.tagline || '';
    if (n < 3) return 'solo';
    if (n >= 5) return 'scatter';
    if (data.project.logo && name.length <= 10) return 'centered';
    if (name.length > 10 || tagline.length > 45) return 'split-left';
    return 'split-right';
  }

  function renderSet(data) {
    if (data.layout && data.layout !== 'auto') return [data.layout];
    var n = data.screens.length;
    var first = autoLayout(data);
    var set = [first];
    for (var i = 0; i < PRIORITY.length && set.length < MAX_SET; i++) {
      var a = PRIORITY[i];
      if (a !== first && n >= ELIGIBILITY[a]) set.push(a);
    }
    return set;
  }

  NS.layout = {
    ELIGIBILITY: ELIGIBILITY,
    PRIORITY: PRIORITY,
    MAX_SET: MAX_SET,
    eligible: eligible,
    autoLayout: autoLayout,
    renderSet: renderSet
  };
})(window);
```

- [ ] **Step 4: Jalankan test**

Run: `bash tests/run.sh`
Expected: seluruh assertion layout PASS.

- [ ] **Step 5: Commit**

```bash
git add assets/js/layout.js tests/test.html
git commit -m "feat: pick auto layout and assemble render set from screen count"
```

---

## Task 5: Aset ter-embed — font base64 & SVG dekorasi inline

**Files:**
- Create: `assets/fonts/Outfit-Bold.woff2`, `assets/fonts/Outfit-SemiBold.woff2`, `assets/fonts/Inter-Regular.woff2`, `assets/fonts/Inter-Medium.woff2`
- Create: `assets/decor/brush-01.svg` … `brush-04.svg`, `blob-01.svg` … `blob-03.svg`, `dots.svg`, `grid.svg`
- Create: `scripts/build-assets.sh`
- Create: `scripts/build-assets.ps1`
- Create (generated): `assets/fonts.css`, `assets/js/decor.js`
- Modify: `tests/test.html`

**Interfaces:**
- Consumes: `Assert`.
- Produces — `window.CoverMaker.decor`:
  - `SHAPES` — objek `{brush: svgString, blob: svgString, dots: svgString, grid: svgString}`
  - `forArchetype(archetype) -> 'brush'|'blob'|'dots'|'grid'`
  - `resolve(decorSetting, archetype) -> string|null` — `null` kalau `'none'`

**Catatan pengadaan font:** file woff2 tidak diunduh oleh script (Global Constraint: tanpa jaringan saat render — pengunduhan satu kali saat menyiapkan repo boleh, tapi harus manual oleh manusia). Ambil Outfit dan Inter dari Google Fonts, unduh woff2 subset latin, taruh di `assets/fonts/`. Keduanya SIL Open Font License 1.1; sertakan `assets/fonts/OFL.txt`.

- [ ] **Step 1: Tulis test yang gagal**

Tambahkan ke `tests/test.html`:

```html
<script src="../assets/js/decor.js"></script>
<script>
var D = CoverMaker.decor;

['brush', 'blob', 'dots', 'grid'].forEach(function (k) {
  Assert.ok(typeof D.SHAPES[k] === 'string' && D.SHAPES[k].indexOf('<svg') === 0,
            'decor: SHAPES.' + k + ' is inline svg markup');
  Assert.ok(D.SHAPES[k].indexOf('currentColor') !== -1,
            'decor: SHAPES.' + k + ' is recolourable via currentColor');
  Assert.ok(D.SHAPES[k].indexOf('http') === -1,
            'decor: SHAPES.' + k + ' has no external reference');
});

Assert.eq(D.forArchetype('split-right'), 'brush', 'decor: split-right maps to brush');
Assert.eq(D.forArchetype('split-left'), 'brush', 'decor: split-left maps to brush');
Assert.eq(D.forArchetype('centered'), 'dots', 'decor: centered maps to dots');
Assert.eq(D.forArchetype('scatter'), 'blob', 'decor: scatter maps to blob');
Assert.eq(D.forArchetype('solo'), 'blob', 'decor: solo maps to blob');

Assert.eq(D.resolve('none', 'centered'), null, 'decor: none resolves to null');
Assert.eq(D.resolve('grid', 'centered'), D.SHAPES.grid, 'decor: explicit choice wins over archetype');
Assert.eq(D.resolve('auto', 'centered'), D.SHAPES.dots, 'decor: auto follows the archetype');
</script>
```

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `bash tests/run.sh`
Expected: gagal — `CoverMaker.decor is undefined`.

- [ ] **Step 3: Tulis SVG sumber**

Semua memakai `fill="currentColor"` supaya bisa diwarnai dari CSS, dan `viewBox` tanpa `width`/`height` supaya bisa diregangkan container.

`assets/decor/brush-01.svg` — sapuan organik miring (acuan cover3):

```svg
<svg viewBox="0 0 800 900" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="none"><path fill="currentColor" d="M812 -20 C700 90 640 150 596 240 C548 338 560 392 512 470 C470 540 402 566 352 640 C300 716 296 800 240 920 L812 920 Z"/></svg>
```

`assets/decor/brush-02.svg` — varian lebih landai:

```svg
<svg viewBox="0 0 800 900" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="none"><path fill="currentColor" d="M812 -20 C660 120 620 210 590 300 C556 402 588 452 540 528 C494 600 410 620 366 700 C322 780 320 852 288 920 L812 920 Z"/></svg>
```

`assets/decor/brush-03.svg` — varian lebih tajam:

```svg
<svg viewBox="0 0 800 900" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="none"><path fill="currentColor" d="M812 -20 C724 60 700 176 640 250 C580 324 606 400 548 460 C490 520 432 528 388 610 C344 692 356 806 316 920 L812 920 Z"/></svg>
```

`assets/decor/brush-04.svg` — varian paling tenang:

```svg
<svg viewBox="0 0 800 900" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="none"><path fill="currentColor" d="M812 -20 C690 140 664 260 630 350 C598 434 620 500 578 570 C534 642 452 662 412 740 C374 814 372 862 348 920 L812 920 Z"/></svg>
```

`assets/decor/blob-01.svg` — lingkaran besar bleed dari bawah:

```svg
<svg viewBox="0 0 1000 1000" xmlns="http://www.w3.org/2000/svg"><circle cx="500" cy="620" r="470" fill="currentColor"/></svg>
```

`assets/decor/blob-02.svg`:

```svg
<svg viewBox="0 0 1000 1000" xmlns="http://www.w3.org/2000/svg"><ellipse cx="500" cy="660" rx="520" ry="440" fill="currentColor"/></svg>
```

`assets/decor/blob-03.svg`:

```svg
<svg viewBox="0 0 1000 1000" xmlns="http://www.w3.org/2000/svg"><path fill="currentColor" d="M500 150 C740 150 920 330 920 570 C920 810 740 990 500 990 C260 990 80 810 80 570 C80 330 260 150 500 150 Z"/></svg>
```

`assets/decor/dots.svg` — grid titik (acuan cover1); dipakai sebagai pattern yang di-tile:

```svg
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs><pattern id="d" width="12.5" height="12.5" patternUnits="userSpaceOnUse"><circle cx="2" cy="2" r="1.6" fill="currentColor"/></pattern></defs><rect width="100" height="100" fill="url(#d)"/></svg>
```

`assets/decor/grid.svg`:

```svg
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs><pattern id="g" width="20" height="20" patternUnits="userSpaceOnUse"><path d="M20 0 L0 0 0 20" fill="none" stroke="currentColor" stroke-width="0.7"/></pattern></defs><rect width="100" height="100" fill="url(#g)"/></svg>
```

**Peringatan `id` bentrok:** `dots.svg` dan `grid.svg` memakai `<pattern id>`. Karena beberapa SVG bisa inline di satu halaman, generator di Step 4 harus memberi prefix unik pada tiap `id` dan `url(#…)`. Sudah ditangani di script.

- [ ] **Step 4: Tulis `scripts/build-assets.sh`**

```bash
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
  svg="$(printf '%s' "$svg" | sed -e "s/id=\"/id=\"cm-${key}-/g" -e "s/url(#/url(#cm-${key}-/g")"
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
    'scatter': 'blob',
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
```

- [ ] **Step 5: Tulis `scripts/build-assets.ps1`**

```powershell
$ErrorActionPreference = 'Stop'
$root  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$fonts = Join-Path $root 'assets\fonts'
$decor = Join-Path $root 'assets\decor'

function ConvertTo-B64($p) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) }

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
$css -join "`n" | Out-File -FilePath (Join-Path $root 'assets\fonts.css') -Encoding utf8

$shapes = @{ brush='brush-01.svg'; blob='blob-01.svg'; dots='dots.svg'; grid='grid.svg' }
$js = @('// GENERATED oleh scripts/build-assets.ps1. Jangan diedit tangan.',
        '(function (global) {',
        '  var NS = global.CoverMaker = global.CoverMaker || {};',
        '  var SHAPES = {')
foreach ($k in @('brush','blob','dots','grid')) {
  $svg = (Get-Content (Join-Path $decor $shapes[$k]) -Raw) -replace "`r?`n", ''
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
    'scatter': 'blob',
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
$js -join "`n" | Out-File -FilePath (Join-Path $root 'assets\js\decor.js') -Encoding utf8

Write-Output 'generated: assets/fonts.css, assets/js/decor.js'
```

- [ ] **Step 6: Jalankan generator, lalu jalankan test**

```bash
chmod +x scripts/build-assets.sh
bash scripts/build-assets.sh
bash tests/run.sh
```

Expected: `generated: assets/fonts.css, assets/js/decor.js`, lalu seluruh assertion decor PASS.

- [ ] **Step 7: Verifikasi `fonts.css` tidak punya referensi eksternal**

Run: `grep -c 'url(data:font/woff2;base64,' assets/fonts.css` → harus `4`
Run: `grep -c 'http' assets/fonts.css` → harus `0`

- [ ] **Step 8: Commit**

```bash
git add assets/fonts assets/decor assets/fonts.css assets/js/decor.js scripts/build-assets.sh scripts/build-assets.ps1 tests/test.html
git commit -m "feat: embed fonts as base64 and decor SVGs as inline markup"
```

---

## Task 6: Generator fixture

Screenshot dummy dibuat memakai Chrome itu sendiri, sehingga tidak melanggar aturan nol dependency.

**Files:**
- Create: `tests/make-fixture.sh`
- Create: `tests/make-fixture.ps1`
- Create: `tests/fixture/_source.html`
- Create (generated): `tests/fixture/home.png`, `tests/fixture/chat.png`, `tests/fixture/detail.png`
- Create: `tests/fixture/cover.json`

**Interfaces:**
- Consumes: `scripts/find-browser.sh` / `.ps1` dari Task 1.
- Produces: tiga PNG 1080×2340 dan `tests/fixture/cover.json` yang valid menurut Task 3.

- [ ] **Step 1: Tulis `tests/fixture/_source.html`**

Halaman ini digambar tiga kali dengan `?screen=` berbeda. Warnanya sengaja teal (H≈160) supaya Test #2 dan pipeline palet punya sinyal yang bisa diprediksi.

```html
<!doctype html>
<meta charset="utf-8">
<title>fixture screen</title>
<style>
  html, body { margin: 0; background: #fff; }
  body { width: 1080px; height: 2340px; font-family: system-ui, sans-serif; }
  .bar { height: 90px; background: #0f6b52; }
  .hero { height: 620px; background: #148a68; color: #fff; padding: 80px; box-sizing: border-box; }
  .hero h1 { font-size: 96px; margin: 0 0 24px; }
  .hero p { font-size: 46px; margin: 0; opacity: .9; }
  .card { margin: 60px 80px; height: 300px; border-radius: 40px; background: #e8f5f0; }
  .card.alt { background: #d3ece3; }
  .fill { background: #148a68; }
</style>
<div class="bar"></div>
<div class="hero"><h1 id="t">Home</h1><p>fixture screen for cover-maker tests</p></div>
<div class="card"></div>
<div class="card alt"></div>
<div class="card"></div>
<div class="card alt fill"></div>
<script>
  var s = new URLSearchParams(location.search).get('screen') || 'Home';
  document.getElementById('t').textContent = s;
</script>
```

- [ ] **Step 2: Tulis `tests/make-fixture.sh`**

```bash
#!/usr/bin/env bash
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
BROWSER="$("$HERE/../scripts/find-browser.sh")" || { echo "no browser found"; exit 1; }

shot() {
  "$BROWSER" --headless=new --disable-gpu --hide-scrollbars \
    --window-size=1080,2340 --virtual-time-budget=4000 \
    --screenshot="$HERE/fixture/$1.png" \
    "file://$HERE/fixture/_source.html?screen=$2" >/dev/null 2>&1
}

shot home   Home
shot chat   Chat
shot detail Detail
ls -l "$HERE/fixture"/*.png
```

- [ ] **Step 3: Tulis `tests/make-fixture.ps1`**

```powershell
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$browser = & "$here\..\scripts\find-browser.ps1"
if (-not $browser) { Write-Output 'no browser found'; exit 1 }
$u = ($here -replace '\\','/')

foreach ($p in @(@('home','Home'), @('chat','Chat'), @('detail','Detail'))) {
  & $browser --headless=new --disable-gpu --hide-scrollbars `
    --window-size=1080,2340 --virtual-time-budget=4000 `
    "--screenshot=$here\fixture\$($p[0]).png" `
    "file:///$u/fixture/_source.html?screen=$($p[1])" | Out-Null
}
Get-ChildItem "$here\fixture\*.png" | Select-Object Name, Length
```

- [ ] **Step 4: Tulis `tests/fixture/cover.json`**

```json
{
  "project": {
    "name": "TripMate",
    "tagline": "Your smart travel assistant for seamless exploration"
  },
  "screens": [
    { "src": "home.png",   "role": "hero" },
    { "src": "chat.png",   "role": "support" },
    { "src": "detail.png", "role": "support" }
  ],
  "meta": "C241-PS064",
  "layout": "auto",
  "palette": { "mode": "auto" },
  "decor": "auto",
  "output": { "dir": "../../cover-output-test", "scale": 2 }
}
```

`tagline` di sini 51 karakter (>45), jadi `autoLayout` akan memilih `split-left` dan render set berisi 4 arketipe — persis yang diasumsikan Test #6.

- [ ] **Step 5: Jalankan generator dan verifikasi**

```bash
chmod +x tests/make-fixture.sh
bash tests/make-fixture.sh
```

Expected: tiga PNG muncul, masing-masing >30KB. Buka salah satunya dengan Read untuk memastikan isinya benar-benar tampilan app dummy, bukan halaman putih.

- [ ] **Step 6: Commit**

```bash
git add tests/make-fixture.sh tests/make-fixture.ps1 tests/fixture
git commit -m "test: generate fixture screenshots with headless Chrome"
```

Catatan: PNG fixture **di-commit** (bukan di-gitignore) supaya test bisa jalan tanpa langkah generate lebih dulu. Ukurannya kecil.

---

## Task 7: Template halaman + pipeline render self-contained

**Files:**
- Create: `assets/template.html`
- Create: `scripts/render.sh`
- Create: `scripts/render.ps1`
- Modify: `tests/run.sh`, `tests/run.ps1` (tambah Test #5)

**Interfaces:**
- Consumes: `assets/fonts.css`, `assets/cover.css` (belum ada — dibuat Task 8; untuk sekarang render script hanya harus tahan kalau file itu belum ada), `assets/js/*.js`.
- Produces:
  - `bash scripts/render.sh <path/to/cover.json>` → menulis `render-<layout>.html` dan `<layout>.png` ke `output.dir`, mencetak satu baris per file yang dihasilkan.
  - Placeholder di `template.html`: `__STYLES__`, `__SCRIPTS__`, `__COVER_DATA__`, `__LAYOUT__`, `__SCALE__`.

- [ ] **Step 1: Tulis `assets/template.html`**

```html
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>cover</title>
<style>__STYLES__</style>
</head>
<body>
<div id="stage"></div>
<script>
window.COVER_DATA = __COVER_DATA__;
window.COVER_LAYOUT = "__LAYOUT__";
window.COVER_SCALE = __SCALE__;
</script>
<script>__SCRIPTS__</script>
</body>
</html>
```

- [ ] **Step 2: Tulis `scripts/render.sh`**

```bash
#!/usr/bin/env bash
# Bangun halaman self-contained lalu screenshot lewat headless Chrome.
# Tugasnya murni mekanis: substitusi placeholder + panggil browser.
set -eu

COVER_JSON="${1:-cover.json}"
[ -f "$COVER_JSON" ] || { echo "error: $COVER_JSON not found"; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$(cd "$(dirname "$COVER_JSON")" && pwd)"

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
SRCS="$(printf '%s' "$DATA_JSON" | grep -oE '"(src|logo)"[[:space:]]*:[[:space:]]*"[^"]+"' \
        | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/' | sort -u)"

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
STYLES="$(cat "$ROOT/assets/fonts.css" "$ROOT/assets/cover.css" 2>/dev/null || cat "$ROOT/assets/fonts.css")"
SCRIPTS="$(cat "$ROOT/assets/js/palette.js" "$ROOT/assets/js/validate.js" \
               "$ROOT/assets/js/layout.js" "$ROOT/assets/js/decor.js" \
               "$ROOT/assets/js/render.js")"

# Ambil output.dir, output.scale, dan daftar layout dari cover.js lewat sekali
# jalan headless: satu-satunya sumber kebenaran untuk render set adalah layout.js.
BROWSER="$("$ROOT/scripts/find-browser.sh")" || BROWSER=""

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
  PLAN_OUT="$("$BROWSER" --headless=new --disable-gpu --virtual-time-budget=4000 \
              --dump-dom "file://$PLAN_HTML" 2>/dev/null)"
  if printf '%s' "$PLAN_OUT" | grep -q 'ERROR '; then
    printf '%s\n' "$PLAN_OUT" | grep -oE 'ERROR [^<]*'
    exit 1
  fi
  printf '%s\n' "$PLAN_OUT" | grep -oE 'WARN [^<]*' || true
  LAYOUTS="$(printf '%s' "$PLAN_OUT" | grep -oE 'SET [^<]*' | sed 's/^SET //' | tr ',' ' ')"
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
      gsub(/__COVER_DATA__/, "\x01DATA\x01", line)
      gsub(/__STYLES__/,     "\x01ST\x01",   line)
      gsub(/__SCRIPTS__/,    "\x01SC\x01",   line)
      gsub(/__LAYOUT__/,     ENVIRON["LAY"], line)
      gsub(/__SCALE__/,      ENVIRON["SCL"], line)
      n = split(line, parts, "\x01")
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

  "$BROWSER" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --virtual-time-budget=8000 \
    --window-size="$WIDTH,$HEIGHT" \
    --screenshot="$OUT_DIR/$layout.png" "file://$PAGE" >/dev/null 2>&1
  echo "png:  $OUT_DIR/$layout.png"
done

if [ -z "$BROWSER" ]; then
  echo "warn: no Chromium-based browser found. The HTML pages above are fully"
  echo "warn: self-contained - open one in any browser and screenshot it manually."
  exit 2
fi
```

- [ ] **Step 3: Tulis `scripts/render.ps1`**

Padanan PowerShell dengan perilaku identik.

```powershell
param([string]$CoverJson = 'cover.json')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $CoverJson)) { Write-Output "error: $CoverJson not found"; exit 1 }

$root    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$srcDir  = Split-Path -Parent (Resolve-Path $CoverJson)
$dataRaw = Get-Content $CoverJson -Raw

function Get-Mime($p) {
  switch ([IO.Path]::GetExtension($p).ToLower()) {
    '.png'  { 'image/png' }    '.jpg' { 'image/jpeg' }  '.jpeg' { 'image/jpeg' }
    '.webp' { 'image/webp' }   '.svg' { 'image/svg+xml' }
    default { 'application/octet-stream' }
  }
}

$srcs = [regex]::Matches($dataRaw, '"(?:src|logo)"\s*:\s*"([^"]+)"') |
        ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
foreach ($rel in $srcs) {
  $abs = Join-Path $srcDir $rel
  if (-not (Test-Path $abs)) { Write-Output "error: image not found: $rel"; exit 1 }
  $uri = 'data:' + (Get-Mime $abs) + ';base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($abs))
  $dataRaw = $dataRaw.Replace('"' + $rel + '"', '"' + $uri + '"')
}

$styles = (Get-Content (Join-Path $root 'assets\fonts.css') -Raw)
$coverCss = Join-Path $root 'assets\cover.css'
if (Test-Path $coverCss) { $styles += "`n" + (Get-Content $coverCss -Raw) }

$scripts = @('palette.js','validate.js','layout.js','decor.js','render.js') |
  ForEach-Object { Get-Content (Join-Path $root "assets\js\$_") -Raw }
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
  (Get-Content (Join-Path $root 'assets\js\validate.js') -Raw),
  (Get-Content (Join-Path $root 'assets\js\layout.js') -Raw),
  "var D = $dataRaw;", @"
  try {
    var v = CoverMaker.validate.validate(D);
    document.getElementById('out').textContent =
      'SET ' + CoverMaker.layout.renderSet(v.data).join(',') +
      '\n' + v.warnings.map(function (w) { return 'WARN ' + w; }).join('\n');
  } catch (e) { document.getElementById('out').textContent = 'ERROR ' + e.message; }
</script>
"@)
$planParts -join "`n" | Out-File $planHtml -Encoding utf8

$layouts = @('split-right')
if ($browser) {
  $planOut = (& $browser --headless=new --disable-gpu --virtual-time-budget=4000 `
              --dump-dom "file:///$(($planHtml -replace '\\','/'))") -join "`n"
  if ($planOut -match 'ERROR ([^<]*)') { Write-Output "ERROR $($Matches[1])"; exit 1 }
  [regex]::Matches($planOut, 'WARN [^<]*') | ForEach-Object { Write-Output $_.Value }
  $layouts = ([regex]::Match($planOut, 'SET ([^<\n]*)')).Groups[1].Value -split ','
}
Remove-Item $planHtml -Force -ErrorAction SilentlyContinue

$w = 1600 * [int]$scale; $h = 900 * [int]$scale
$tpl = Get-Content (Join-Path $root 'assets\template.html') -Raw

foreach ($layout in $layouts) {
  $page = Join-Path $outDir "render-$layout.html"
  $html = $tpl.Replace('__STYLES__', $styles).Replace('__SCRIPTS__', $scripts).
               Replace('__COVER_DATA__', $dataRaw).Replace('__LAYOUT__', $layout).
               Replace('__SCALE__', $scale)
  $html | Out-File $page -Encoding utf8
  Write-Output "html: $page"
  if (-not $browser) { continue }
  & $browser --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
    --virtual-time-budget=8000 --window-size="$w,$h" `
    "--screenshot=$(Join-Path $outDir "$layout.png")" `
    "file:///$(($page -replace '\\','/'))" | Out-Null
  Write-Output "png:  $(Join-Path $outDir "$layout.png")"
}

if (-not $browser) {
  Write-Output 'warn: no Chromium-based browser found. The HTML pages above are fully'
  Write-Output 'warn: self-contained - open one in any browser and screenshot it manually.'
  exit 2
}
```

- [ ] **Step 4: Buat stub `assets/js/render.js` supaya pipeline bisa dijalankan**

```javascript
// Stub sementara. Diisi penuh di Task 8.
(function (global) {
  document.getElementById('stage').textContent =
    'layout=' + global.COVER_LAYOUT + ' name=' + global.COVER_DATA.project.name;
})(window);
```

- [ ] **Step 5: Tambahkan Test #5 ke `tests/run.sh`**

Sisipkan sebelum baris `echo "--- unit tests passed ---"`:

```bash
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
```

- [ ] **Step 6: Tambahkan Test #5 ke `tests/run.ps1`**

```powershell
$outDir = Join-Path $here '..\cover-output-test'
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
& "$here\..\scripts\render.ps1" "$here\fixture\cover.json" | Out-Null

$selfOk = $true
$pages = Get-ChildItem (Join-Path $outDir 'render-*.html') -ErrorAction SilentlyContinue
if (-not $pages) { Write-Output 'FAIL :: no render-*.html produced'; exit 1 }
foreach ($p in $pages) {
  $t = Get-Content $p.FullName -Raw
  if ($t -match 'file://|http://|https://') {
    Write-Output "FAIL :: $($p.Name) contains an external URL"; $selfOk = $false
  }
  $bad = [regex]::Matches($t, '(src|href)="([^"]*)"') |
         Where-Object { $_.Groups[2].Value -notlike 'data:*' }
  if ($bad) { Write-Output "FAIL :: $($p.Name) has a non-data: src/href"; $selfOk = $false }
}
if ($selfOk) { Write-Output 'PASS :: render pages are fully self-contained' } else { exit 1 }
```

- [ ] **Step 7: Jalankan seluruh test**

```bash
chmod +x scripts/render.sh
bash tests/run.sh
```

Expected: seluruh unit test PASS, ditambah `PASS :: render pages are fully self-contained`. Direktori `cover-output-test/` berisi 4 file `render-*.html` dan 4 PNG (isinya masih teks stub — itu wajar di tahap ini).

- [ ] **Step 8: Verifikasi manual fallback tanpa browser**

Ganti sementara `scripts/find-browser.sh` supaya langsung `exit 1` di baris pertama, lalu:

```bash
bash scripts/render.sh tests/fixture/cover.json; echo "exit=$?"
```

Expected: `render-split-right.html` tetap ditulis, muncul dua baris `warn:`, dan `exit=2`. **Kembalikan `find-browser.sh` setelah terbukti.**

Ini memverifikasi invarian §12.7 — skill tidak pulang dengan tangan kosong.

- [ ] **Step 9: Tambahkan `cover-output-test/` ke `.gitignore` lalu commit**

```bash
printf 'cover-output-test/\n' >> .gitignore
git add assets/template.html assets/js/render.js scripts/render.sh scripts/render.ps1 tests/run.sh tests/run.ps1 .gitignore
git commit -m "feat: build self-contained render pages and screenshot them headless"
```

---

## Task 8: Perakitan DOM + CSS dasar + arketipe `solo`

**Files:**
- Create: `assets/cover.css`
- Modify: `assets/js/render.js` (ganti stub Task 7 sepenuhnya)

**Interfaces:**
- Consumes: `CoverMaker.palette`, `CoverMaker.validate`, `CoverMaker.layout`, `CoverMaker.decor`; global `COVER_DATA`, `COVER_LAYOUT`, `COVER_SCALE`.
- Produces — `window.CoverMaker.render`:
  - `fitWordmark(el, maxPx, containerPx) -> number` (ukuran font final)
  - `isLightBackedLogo(img) -> boolean`
  - `mount() -> void` — merakit seluruh DOM ke `#stage`

- [ ] **Step 1: Tulis `assets/cover.css` (token, kanvas, device frame, `solo`)**

```css
/* Kanvas logis 1600x900. zoom menaikkan seluruhnya ke skala render. */
html { zoom: var(--scale, 2); }
html, body { margin: 0; padding: 0; background: #fff; }

.canvas {
  position: relative;
  width: 1600px;
  height: 900px;
  overflow: hidden;
  background: linear-gradient(135deg, var(--surface-a) 0%, var(--surface-b) 100%);
  font-family: Inter, system-ui, sans-serif;
  -webkit-font-smoothing: antialiased;
}

/* --- lapisan dekorasi --- */
.decor {
  position: absolute;
  inset: 0;
  color: var(--accent);
  opacity: .16;
  pointer-events: none;
}
.decor svg { width: 100%; height: 100%; display: block; }

/* --- device frame --- */
.phone {
  --pw: 300px;
  position: absolute;
  width: var(--pw);
  aspect-ratio: 9 / 19.5;
  padding: calc(var(--pw) * .011);
  border-radius: calc(var(--pw) * .049);   /* 0.038 radius layar + 0.011 bezel */
  background: #111318;
  box-sizing: border-box;
  box-shadow:
    0 calc(var(--pw) * .09) calc(var(--pw) * .19) rgba(14, 22, 30, .18),
    0 calc(var(--pw) * .02) calc(var(--pw) * .05) rgba(14, 22, 30, .22);
}
.phone::after {                            /* notch */
  content: '';
  position: absolute;
  top: calc(var(--pw) * .022);
  left: 50%;
  transform: translateX(-50%);
  width: calc(var(--pw) * .30);
  height: calc(var(--pw) * .055);
  border-radius: 999px;
  background: #111318;
  z-index: 2;
}
.phone__screen {
  width: 100%;
  height: 100%;
  border-radius: calc(var(--pw) * .038);
  overflow: hidden;
  background: #fff;
}
.phone__screen img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: top;   /* rasio meleset dipotong dari bawah, tidak digepengkan */
  display: block;
}

/* --- blok teks --- */
.copy { position: absolute; }
.copy__logo { display: block; max-height: 96px; max-width: 300px; margin-bottom: 28px; }
.copy__logo--boxed {
  background: #fff;
  border-radius: 24px;
  padding: 14px 18px;
  box-shadow: 0 8px 22px rgba(14, 22, 30, .10);
  box-sizing: content-box;
}
.copy__name {
  font-family: Outfit, system-ui, sans-serif;
  font-weight: 700;
  color: var(--base);
  line-height: .98;
  letter-spacing: -.02em;
  margin: 0;
  white-space: nowrap;
}
.copy__rule {
  height: 4px;
  width: 190px;
  background: var(--accent);
  border-radius: 999px;
  margin: 26px 0 24px;
}
.copy__tagline {
  font-size: 34px;
  line-height: 1.35;
  color: var(--ink);
  margin: 0;
  max-width: 620px;
}
.copy__badges { display: flex; align-items: center; gap: 22px; margin-top: 44px; }
.copy__badges img { max-height: 68px; max-width: 190px; object-fit: contain; }
.copy__meta {
  font-family: Outfit, system-ui, sans-serif;
  font-weight: 600;
  font-size: 30px;
  letter-spacing: .04em;
  color: var(--accent);
  margin-top: 26px;
}

/* --- arketipe: solo --- */
.layout-solo .copy { left: 110px; top: 50%; transform: translateY(-50%); width: 640px; }
.layout-solo .stage { position: absolute; right: 130px; top: 50%; transform: translateY(-50%); }
.layout-solo .stage .phone { --pw: 380px; position: relative; transform: rotate(-5deg); }
.layout-solo .decor { opacity: .14; }
```

- [ ] **Step 2: Tulis `assets/js/render.js`**

```javascript
(function (global) {
  var NS = global.CoverMaker = global.CoverMaker || {};
  var P = NS.palette;

  // Kecilkan wordmark sampai muat di kolomnya. Maksimum 150px pada skala logis.
  function fitWordmark(el, maxPx, containerPx) {
    var size = maxPx;
    el.style.fontSize = size + 'px';
    while (el.scrollWidth > containerPx && size > 28) {
      size -= 2;
      el.style.fontSize = size + 'px';
    }
    return size;
  }

  // Logo PNG berlatar terang jadi kotak kaku di atas gradient. Deteksi lewat
  // keempat sudut: kalau semuanya opak dan terang, beri container putih.
  function isLightBackedLogo(img) {
    var c = document.createElement('canvas');
    c.width = 16; c.height = 16;
    var ctx = c.getContext('2d');
    ctx.drawImage(img, 0, 0, 16, 16);
    var d;
    try { d = ctx.getImageData(0, 0, 16, 16).data; }
    catch (e) { return false; }   // seharusnya tidak terjadi: semua gambar data: URI
    var corners = [0, 15, 16 * 15, 16 * 15 + 15];
    for (var i = 0; i < corners.length; i++) {
      var o = corners[i] * 4;
      if (d[o + 3] < 200) return false;
      var hsl = P.rgbToHsl(d[o], d[o + 1], d[o + 2]);
      if (hsl.l < 0.85) return false;
    }
    return true;
  }

  function el(tag, cls, parent) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (parent) parent.appendChild(n);
    return n;
  }

  function loadImage(src) {
    return new Promise(function (resolve, reject) {
      var img = new Image();
      img.onload = function () { resolve(img); };
      img.onerror = function () { reject(new Error('image failed to load')); };
      img.src = src;
    });
  }

  function resolvePalette(data, heroImg) {
    if (data.palette.mode === 'manual') {
      return {
        css: {
          '--base': data.palette.base, '--accent': data.palette.accent,
          '--ink': data.palette.ink, '--surface-a': data.palette.surfaceA,
          '--surface-b': data.palette.surfaceB
        },
        fallback: false
      };
    }
    var c = document.createElement('canvas');
    c.width = 100; c.height = 200;
    var ctx = c.getContext('2d');
    ctx.drawImage(heroImg, 0, 0, 100, 200);
    var got = P.extractHue(ctx.getImageData(0, 0, 100, 200));
    var p = P.derive(got.hue);
    return {
      css: {
        '--base': P.toCss(p.base), '--accent': P.toCss(p.accent), '--ink': P.toCss(p.ink),
        '--surface-a': P.toCss(p.surfaceA), '--surface-b': P.toCss(p.surfaceB)
      },
      fallback: got.fallback,
      hue: got.hue
    };
  }

  function buildPhone(parent, src) {
    var phone = el('div', 'phone', parent);
    var screen = el('div', 'phone__screen', phone);
    var img = el('img', null, screen);
    img.src = src;
    return phone;
  }

  function mount() {
    var raw = global.COVER_DATA;
    var layout = global.COVER_LAYOUT;
    document.documentElement.style.setProperty('--scale', global.COVER_SCALE || 2);

    var v = NS.validate.validate(raw);
    var data = v.data;

    var stageRoot = document.getElementById('stage');
    var canvas = el('div', 'canvas layout-' + layout, stageRoot);

    var order = data.screens.slice().sort(function (a, b) {
      return (a.role === 'hero' ? -1 : 0) - (b.role === 'hero' ? -1 : 0);
    });

    return loadImage(order[0].src).then(function (heroImg) {
      var pal = resolvePalette(data, heroImg);
      for (var k in pal.css) canvas.style.setProperty(k, pal.css[k]);
      if (pal.fallback) console.log('WARN palette fell back to hue 215 (no dominant brand hue)');

      // dekorasi
      var svg = NS.decor.resolve(data.decor, layout);
      if (svg) el('div', 'decor', canvas).innerHTML = svg;

      // panggung mockup
      var stage = el('div', 'stage', canvas);
      order.forEach(function (s) { buildPhone(stage, s.src); });

      // blok teks
      var copy = el('div', 'copy', canvas);
      var logoStep = Promise.resolve();
      if (data.project.logo) {
        logoStep = loadImage(data.project.logo).then(function (logoImg) {
          var wrap = el('div', null, copy);
          wrap.className = 'copy__logo' + (isLightBackedLogo(logoImg) ? ' copy__logo--boxed' : '');
          wrap.appendChild(logoImg);
          logoImg.style.maxHeight = '96px';
          logoImg.style.display = 'block';
        });
      }

      return logoStep.then(function () {
        var name = el('h1', 'copy__name', copy);
        name.textContent = data.project.name;
        el('div', 'copy__rule', copy);
        var tag = el('p', 'copy__tagline', copy);
        tag.textContent = data.project.tagline;

        if (data.badges.length) {
          var bar = el('div', 'copy__badges', copy);
          data.badges.forEach(function (b) {
            var i = el('img', null, bar);
            i.src = b.src;
            i.alt = b.label || '';
          });
        }
        if (data.meta) el('div', 'copy__meta', copy).textContent = data.meta;

        fitWordmark(name, 150, copy.clientWidth);
        document.documentElement.setAttribute('data-ready', '1');
      });
    });
  }

  NS.render = { fitWordmark: fitWordmark, isLightBackedLogo: isLightBackedLogo, mount: mount };
  mount();
})(window);
```

- [ ] **Step 3: Render fixture dengan layout `solo` dan lihat hasilnya**

```bash
bash scripts/render.sh tests/fixture/cover.json
```

Lalu ubah sementara `tests/fixture/cover.json` → `"layout": "solo"`, jalankan lagi, dan **buka `cover-output-test/solo.png` dengan Read**.

Expected: satu HP miring di kanan berisi screenshot fixture, wordmark "TripMate" hijau-teal di kiri, garis aksen, tagline dua baris, `C241-PS064` di bawahnya, background gradient teal muda. Teks terbaca jelas.

Kalau ada yang meleset (teks terpotong, HP keluar kanvas, warna tidak nyambung), setel angkanya di `cover.css` dan ulangi step ini sampai benar. **Kembalikan `"layout": "auto"` setelah selesai.**

- [ ] **Step 4: Jalankan seluruh test, pastikan tidak ada yang rusak**

Run: `bash tests/run.sh`
Expected: semua PASS termasuk Test #5.

- [ ] **Step 5: Commit**

```bash
git add assets/cover.css assets/js/render.js
git commit -m "feat: assemble cover DOM with derived palette and solo layout"
```

---

## Task 9: Empat arketipe sisanya

**Files:**
- Modify: `assets/cover.css` (tambah blok arketipe)

**Interfaces:**
- Consumes: struktur DOM dari Task 8 — `.canvas.layout-<name> > .decor + .stage(.phone × n) + .copy`.
- Produces: aturan CSS untuk `.layout-split-right`, `.layout-split-left`, `.layout-centered`, `.layout-scatter`. Tidak ada perubahan JS.

Semua arketipe memakai DOM yang sama; urutan `.phone` di DOM selalu hero lebih dulu, sisanya mengikuti urutan `cover.json`.

- [ ] **Step 1: Tambahkan `split-right` ke `assets/cover.css`**

```css
/* --- arketipe: split-right (mockup kiri, teks kanan) --- */
.layout-split-right .stage { position: absolute; left: 40px; top: 0; width: 800px; height: 900px; }
.layout-split-right .stage .phone:nth-child(1) { --pw: 340px; left: 200px; top: 96px;  z-index: 1; }
.layout-split-right .stage .phone:nth-child(2) { --pw: 292px; left: 10px;  top: 300px; z-index: 3; }
.layout-split-right .stage .phone:nth-child(3) { --pw: 292px; left: 430px; top: 360px; z-index: 2; }
.layout-split-right .stage .phone:nth-child(4) { display: none; }
.layout-split-right .copy { right: 100px; top: 50%; transform: translateY(-50%); width: 610px; }
.layout-split-right .decor { opacity: .18; }
```

- [ ] **Step 2: Tambahkan `split-left` (cermin)**

```css
/* --- arketipe: split-left (teks kiri, mockup kanan) --- */
.layout-split-left .stage { position: absolute; right: 40px; top: 0; width: 800px; height: 900px; }
.layout-split-left .stage .phone:nth-child(1) { --pw: 340px; right: 200px; top: 96px;  z-index: 1; }
.layout-split-left .stage .phone:nth-child(2) { --pw: 292px; right: 10px;  top: 300px; z-index: 3; }
.layout-split-left .stage .phone:nth-child(3) { --pw: 292px; right: 430px; top: 360px; z-index: 2; }
.layout-split-left .stage .phone:nth-child(4) { display: none; }
.layout-split-left .copy { left: 100px; top: 50%; transform: translateY(-50%); width: 610px; }
.layout-split-left .decor { opacity: .18; transform: scaleX(-1); }
```

- [ ] **Step 3: Tambahkan `centered`**

```css
/* --- arketipe: centered (teks atas tengah, HP berjajar bleed bawah) --- */
.layout-centered .copy {
  left: 50%; top: 72px; transform: translateX(-50%);
  width: 1100px; text-align: center;
}
.layout-centered .copy__logo { margin-left: auto; margin-right: auto; }
.layout-centered .copy__name { letter-spacing: .06em; }
.layout-centered .copy__rule { margin-left: auto; margin-right: auto; }
.layout-centered .copy__tagline { margin-left: auto; margin-right: auto; max-width: 900px; }
.layout-centered .copy__badges { justify-content: center; }

.layout-centered .stage { position: absolute; left: 0; right: 0; top: 470px; height: 430px; }
.layout-centered .stage .phone:nth-child(1) { --pw: 300px; left: 50%; margin-left: -150px; top: 0;   z-index: 3; }
.layout-centered .stage .phone:nth-child(2) { --pw: 268px; left: 50%; margin-left: -520px; top: 60px; z-index: 2; }
.layout-centered .stage .phone:nth-child(3) { --pw: 268px; left: 50%; margin-left: 252px;  top: 60px; z-index: 2; }
.layout-centered .stage .phone:nth-child(4) { display: none; }
.layout-centered .decor { opacity: .22; }
```

Catatan: logo kampus di cover1 acuan berada di pojok kiri atas, bukan di dalam `.copy`. Di sini badge tetap di dalam `.copy` (rata tengah di bawah tagline) supaya DOM seragam di semua arketipe. Perbedaan ini disengaja — menambah slot pojok berarti menambah cabang di JS untuk satu arketipe saja.

- [ ] **Step 4: Tambahkan `scatter`**

```css
/* --- arketipe: scatter (HP miring tersebar, sebagian bleed keluar) --- */
.layout-scatter .stage { position: absolute; left: 0; top: 0; width: 980px; height: 900px; }
.layout-scatter .stage .phone { transform-origin: center; }
.layout-scatter .stage .phone:nth-child(1) { --pw: 300px; left: 500px; top: 120px; transform: rotate(3deg);  z-index: 4; }
.layout-scatter .stage .phone:nth-child(2) { --pw: 262px; left: 190px; top: -80px; transform: rotate(-6deg); z-index: 3; }
.layout-scatter .stage .phone:nth-child(3) { --pw: 262px; left: 210px; top: 430px; transform: rotate(-3deg); z-index: 3; }
.layout-scatter .stage .phone:nth-child(4) { --pw: 240px; left: -90px; top: 190px; transform: rotate(-8deg); z-index: 2; }
.layout-scatter .stage .phone:nth-child(5) { --pw: 240px; left: 560px; top: 610px; transform: rotate(6deg);  z-index: 2; }
.layout-scatter .stage .phone:nth-child(6) { --pw: 226px; left: -40px; top: 690px; transform: rotate(2deg);  z-index: 1; }
.layout-scatter .copy { right: 90px; top: 50%; transform: translateY(-50%); width: 560px; }
.layout-scatter .decor { opacity: .20; }
```

- [ ] **Step 5: Render keempatnya dan periksa satu per satu dengan mata**

```bash
bash tests/make-fixture.sh          # pastikan fixture ada
bash scripts/render.sh tests/fixture/cover.json
```

Lalu **buka keempat PNG di `cover-output-test/` dengan Read** dan periksa daftar §6-langkah-5 pada spec:
wordmark tidak terpotong, tagline tidak menabrak mockup, kontras cukup, tidak ada HP yang menutupi bagian penting HP lain, badge tidak tumpang tindih.

Setel angka `left`/`top`/`--pw` di `cover.css` sampai keempatnya rapi. Ini iterasi visual — ulangi render+lihat sampai puas.

- [ ] **Step 6: Periksa `scatter` dengan 6 screenshot**

Buat sementara `tests/fixture/cover6.json` — salin `cover.json`, ulang `home.png`/`chat.png`/`detail.png` sampai berjumlah 6 screen (tetap tepat satu `hero`), lalu:

```bash
bash scripts/render.sh tests/fixture/cover6.json
```

Expected: `scatter.png` ada dan keenam HP tampak; dua di antaranya terpotong tepi kanvas dengan sengaja. Hapus `cover6.json` setelah selesai.

- [ ] **Step 7: Jalankan seluruh test**

Run: `bash tests/run.sh`
Expected: semua PASS.

- [ ] **Step 8: Commit**

```bash
git add assets/cover.css
git commit -m "feat: add split-right, split-left, centered and scatter archetypes"
```

---

## Task 10: Test end-to-end (Test #6)

**Files:**
- Modify: `tests/run.sh`, `tests/run.ps1`

**Interfaces:**
- Consumes: `scripts/render.sh` / `.ps1`, `tests/fixture/`.
- Produces: assertion `PASS :: e2e …` di output test runner.

- [ ] **Step 1: Tambahkan Test #6 ke `tests/run.sh`**

Sisipkan setelah blok Test #5, sebelum `echo "--- unit tests passed ---"`:

```bash
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
```

- [ ] **Step 2: Tambahkan Test #6 ke `tests/run.ps1`**

```powershell
$e2eOk = $true
$pngs = @(Get-ChildItem (Join-Path $outDir '*.png') -ErrorAction SilentlyContinue)
if ($pngs.Count -ne 4) { Write-Output "FAIL :: e2e expected 4 png, got $($pngs.Count)"; $e2eOk = $false }
foreach ($p in $pngs) {
  if ($p.Length -lt 81920) {
    Write-Output "FAIL :: e2e $($p.Name) is only $($p.Length)B (<80KB), render likely blank"
    $e2eOk = $false
  }
  $b = [IO.File]::ReadAllBytes($p.FullName)
  $w = ($b[16] -shl 24) -bor ($b[17] -shl 16) -bor ($b[18] -shl 8) -bor $b[19]
  $h = ($b[20] -shl 24) -bor ($b[21] -shl 16) -bor ($b[22] -shl 8) -bor $b[23]
  if ($w -ne 3200 -or $h -ne 1800) {
    Write-Output "FAIL :: e2e $($p.Name) is ${w}x${h}, expected 3200x1800"; $e2eOk = $false
  }
}
if ($e2eOk) { Write-Output 'PASS :: e2e render produced 4 valid 3200x1800 covers' } else { exit 1 }
```

- [ ] **Step 3: Jalankan dan pastikan lulus**

Run: `bash tests/run.sh`
Expected: `PASS :: e2e render produced 4 valid 3200x1800 covers`, exit 0.

- [ ] **Step 4: Buktikan Test #6 bisa merah**

Ubah sementara ambangnya jadi `-lt 8192000` (8MB) dan jalankan lagi.
Expected: empat baris `FAIL :: e2e … <80KB…` dan exit 1. **Kembalikan ke `81920`.**

- [ ] **Step 5: Commit**

```bash
git add tests/run.sh tests/run.ps1
git commit -m "test: assert end-to-end fixture render output count, size and dimensions"
```

---

## Task 11: `SKILL.md`

**Files:**
- Create: `SKILL.md`

**Interfaces:**
- Consumes: seluruh perilaku dari Task 1-10.
- Produces: entry point skill. Harus ≤200 baris (invarian spec §12.10).

- [ ] **Step 1: Tulis `SKILL.md`**

```markdown
---
name: project-cover-maker
description: Use when the user wants a portfolio cover image for a mobile app project - builds four 3200x1800 cover variants from the app's real screenshots, with a colour palette derived from the app itself
---

# Project Cover Maker

Membuat cover portfolio untuk project **mobile app**: PNG 3200×1800 berisi mockup HP
dengan screenshot asli, nama project, tagline, dan palet warna yang diturunkan dari
screenshot itu sendiri.

Renderer-nya deterministik dan sengaja bodoh. Kualitas hasilnya ditentukan oleh dua
langkah yang hanya bisa kamu kerjakan: **memilih screenshot** (langkah 2) dan
**memeriksa hasil render** (langkah 5). Jangan lewati keduanya.

## Prasyarat

Chrome / Chromium / Edge terpasang. Tidak ada dependency lain. Kalau tidak ada browser
sama sekali, skill tetap menghasilkan halaman HTML self-contained yang bisa dibuka dan
di-screenshot user secara manual — jangan pernah pulang dengan tangan kosong.

## Alur kerja

### 1. Kumpulkan bahan

Cari screenshot berurutan di: `screenshots/`, `docs/screenshots/`, `assets/screenshots/`,
`docs/`, `example/`, lalu root. Ekstensi: `.png .jpg .jpeg .webp`.

Cari logo: `logo.*`, `ic_launcher*`, `app_icon*`, `icon.*`.
Baca `README.md` untuk nama project dan deskripsi. Kalau ada, ambil nama app dari
`pubspec.yaml`, `build.gradle(.kts)`, atau `package.json`.

Kalau screenshot yang ditemukan **nol**, baca `references/capture-adb.md` dan tawarkan
jalur capture lewat adb.

### 2. Lihat screenshotnya

Buka tiap kandidat dengan Read. Putuskan:

- Yang paling representatif (biasanya home/dashboard) → jadi `hero`.
- Yang paling kaya secara visual (peta, chart, foto, list bergambar) → prioritas tinggi.
- Buang: duplikat, splash kosong, dialog error, screen dengan keyboard terbuka, screen
  berisi placeholder/lorem.

Ambil 3-5 (maksimum 6), urutkan dari yang paling kuat, tandai tepat satu sebagai `hero`.

**Kalau yang layak hanya 1-2, itu sah.** Lanjutkan; layout `solo` memang untuk itu.
Beri tahu user bahwa menambah screenshot membuka layout lain, tapi tetap serahkan hasil.
Jangan pernah menolak user karena screenshot-nya sedikit.

### 3. Tulis `cover.json`

Taruh di folder yang sama dengan screenshot. `src` relatif terhadap file ini.

```json
{
  "project": { "name": "TripMate", "tagline": "Your smart travel assistant", "logo": null },
  "screens": [
    { "src": "home.png",   "role": "hero" },
    { "src": "chat.png",   "role": "support" },
    { "src": "detail.png", "role": "support" }
  ],
  "badges": [],
  "meta": null,
  "layout": "auto",
  "palette": { "mode": "auto" },
  "decor": "auto",
  "output": { "dir": "cover-output", "scale": 2 }
}
```

Batas keras: `name` ≤16 karakter, `tagline` ≤64 karakter, `screens` 1-6 dengan tepat satu
`hero`, `badges` ≤4, `meta` ≤12 karakter.

**Tagline:** satu kalimat manfaat, 6-10 kata. Bukan daftar fitur. Tulis sendiri kalau
README tidak punya kalimat yang enak dipakai.

Biarkan `layout`, `palette.mode`, dan `decor` di `"auto"` kecuali kamu punya alasan.

### 4. Render

```bash
bash scripts/render.sh path/to/cover.json      # macOS/Linux
powershell -File scripts/render.ps1 path/to/cover.json   # Windows
```

Menghasilkan hingga 4 PNG plus `render-*.html` di `output.dir`.

### 5. Periksa hasilnya

**Buka setiap PNG dengan Read.** Periksa:

- Nama project terpotong atau meluber keluar kolom?
- Tagline menabrak mockup atau keluar kanvas?
- Kontras teks terhadap background di posisinya cukup?
- Ada HP yang menutupi bagian penting HP lain?
- Logo tenggelam di background?
- Badge tumpang tindih?

Kalau ada yang gagal: perbaiki `cover.json` (potong tagline, kunci `layout`, kurangi
screen, atau set `palette.mode: "manual"`), lalu render ulang. Mengunci `layout` ke satu
nilai membuat render hanya menghasilkan satu file — itu cara termurah beriterasi.

**Maksimum 2 putaran koreksi.** Setelah itu serahkan hasil terbaik apa adanya sambil
menyebutkan sisa masalahnya.

### 6. Serahkan

Berikan path tiap file plus satu kalimat kenapa layout itu cocok, supaya user gampang
memilih.

## Referensi

- `references/layouts.md` — anatomi tiap arketipe, kapan dipakai. Baca kalau perlu memilih
  layout secara manual.
- `references/capture-adb.md` — protokol capture lewat adb. Baca hanya kalau jalur itu dipakai.

## Yang tidak dikerjakan skill ini

Project non-mobile (web, dashboard, CLI, ML, backend). Frame device hanya phone.
```

- [ ] **Step 2: Verifikasi panjangnya**

Run: `wc -l SKILL.md`
Expected: ≤200. Kalau lewat, pindahkan detail ke `references/`, bukan memadatkan alur kerjanya.

- [ ] **Step 3: Commit**

```bash
git add SKILL.md
git commit -m "docs: add SKILL.md entry point with six-step agent workflow"
```

---

## Task 12: Dokumen referensi

**Files:**
- Create: `references/layouts.md`
- Create: `references/capture-adb.md`

**Interfaces:**
- Consumes: nilai `ELIGIBILITY` dan `PRIORITY` dari Task 4; nama kelas CSS dari Task 8-9.
- Produces: dua dokumen yang dibaca agent sesuai kebutuhan.

- [ ] **Step 1: Tulis `references/layouts.md`**

```markdown
# Anatomi arketipe layout

Kanvas logis 1600×900, dirender 2× menjadi 3200×1800. Semua arketipe memakai DOM yang
sama: `.canvas.layout-<nama>` berisi `.decor`, `.stage` (satu `.phone` per screen, hero
lebih dulu), dan `.copy` (logo, nama, garis aksen, tagline, badge, meta).

## Syarat kelayakan

| Arketipe | Minimum screen |
|---|---|
| `solo` | 1 |
| `split-right` | 2 |
| `split-left` | 2 |
| `centered` | 3 |
| `scatter` | 5 |

## Pemilihan `auto`

Dievaluasi berurutan, yang pertama cocok menang:

1. `screens < 3` → `solo`
2. `screens >= 5` → `scatter`
3. ada logo **dan** nama ≤10 karakter → `centered`
4. nama >10 karakter **atau** tagline >45 karakter → `split-left`
5. selain itu → `split-right`

## Render set

Hasil `auto` selalu masuk dan selalu pertama. Sisanya diisi dari arketipe yang layak
mengikuti urutan `split-right → split-left → centered → scatter → solo`, berhenti di 4.
Kalau `layout` diisi eksplisit, hanya layout itu yang dirender — satu file.

## Tiap arketipe

### `split-right`
Tiga HP menumpuk membentuk fan di kiri; hero paling belakang dan paling tinggi. Teks rata
kiri di kolom kanan. Default paling aman untuk 3 screenshot dengan nama pendek.

### `split-left`
Cermin dari `split-right`. Dipakai kalau nama panjang, karena mata membaca teks lebih dulu.

### `centered`
Logo, nama, garis, tagline ditumpuk rata tengah di sepertiga atas. Tiga HP berjajar
simetris di bawah, bleed keluar batas bawah. Butuh logo mark yang layak; tanpa logo,
bagian atasnya terasa kosong.

### `scatter`
Lima sampai enam HP dimiringkan (−8° s/d +6°) tersebar di ±60% area kiri; beberapa bleed
keluar tepi. Teks di kanan. Paling ramai — pakai kalau screenshot-nya memang bagus semua.

### `solo`
Satu HP besar dimiringkan −5° di kanan, teks besar di kiri. Untuk 1-2 screenshot.

## Menyetel posisi

Semua posisi ada di `assets/cover.css` dalam blok `.layout-<nama>`. Ukuran HP diatur lewat
custom property `--pw` (lebar HP); tinggi, radius, bezel, notch, dan shadow semuanya
diturunkan dari `--pw`, jadi cukup ubah satu angka itu.
```

- [ ] **Step 2: Tulis `references/capture-adb.md`**

```markdown
# Capture screenshot lewat adb

Dipakai hanya kalau jalur folder tidak menemukan screenshot, atau user memintanya.

## Aturan utama

**Jangan menavigasi app sendiri.** Meng-drive UI app asing lewat `uiautomator dump`
sangat rapuh: kamu tidak tahu nama screen-nya, tidak tahu apakah butuh login, dan tidak
tahu tombol mana yang destruktif. Pembagian kerjanya tetap: **user menavigasi, kamu
menangkap.**

## 1. Cek device

```bash
adb devices
```

Kalau tidak ada device `device` (bukan `unauthorized`/`offline`), hentikan jalur ini dan
minta user menunjukkan folder screenshot-nya.

## 2. Nyalakan demo mode

Membuat status bar bersih: jam 09:41, baterai penuh, sinyal penuh, tanpa notifikasi.
Ini yang membedakan cover yang terlihat seperti materi portfolio dari screenshot iseng.

```bash
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command clock   -e hhmm 0941
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
```

## 3. Sesi capture

Ulangi per screen. Tunggu konfirmasi user tiap kali — jangan pernah capture tanpa diminta.

```
kamu : "Buka screen yang mau di-capture, lalu bilang 'oke'."
user : "oke"
kamu : adb exec-out screencap -p > screenshots/01-home.png
kamu : "Tercapture sebagai 01-home.png. Next, atau sudah cukup?"
```

Beri nama file berurutan dan deskriptif (`01-home.png`, `02-detail.png`) supaya urutannya
jelas saat kamu memilih di langkah 2 alur utama.

Berhenti setelah 6 — lebih dari itu tidak terpakai.

## 4. Matikan demo mode

**Selalu jalankan ini setelah selesai**, jangan tinggalkan device user dalam demo mode.

```bash
adb shell am broadcast -a com.android.systemui.demo -e command exit
```

## 5. Lanjutkan alur utama

Kembali ke langkah 2 di `SKILL.md`: lihat hasil capture-nya, pilih dan urutkan.
```

- [ ] **Step 3: Jalankan seluruh test terakhir kali**

Run: `bash tests/run.sh`
Expected: semua PASS, exit 0.

- [ ] **Step 4: Commit**

```bash
git add references/
git commit -m "docs: add layout anatomy and adb capture protocol references"
```

---

## Self-Review

**1. Spec coverage**

| Spec | Task |
|---|---|
| §4.1 perintah render | 7 |
| §4.1.1 self-contained (4 baris tabel) | 5 (font, decor), 7 (gambar, JSON) + Test #5 |
| §4.2 tiga aturan portabilitas | Global Constraints + Task 5 Step 7 |
| §5 struktur file | seluruh task |
| §5.1 empat tugas render script | 7 |
| §6 alur kerja agent 6 langkah | 11 (`SKILL.md`) |
| §7.1 field `cover.json` | 3 |
| §7.2 aturan validasi (8 baris) | 3, satu assertion per baris |
| §8.1 kanvas & unit relatif | 8 (`html{zoom}`, `--pw`) |
| §8.2 lima arketipe | 8 (`solo`), 9 (empat sisanya) |
| §8.3 kelayakan + auto + render set | 4 |
| §8.4 device frame | 8 |
| §8.5 ekstraksi & penurunan palet | 2 |
| §8.6 lapisan dekorasi | 5 |
| §8.7 tipografi + fitting wordmark | 5 (font), 8 (`fitWordmark`) |
| §9.1 jalur folder | 11 |
| §9.2 jalur adb + demo mode | 12 |
| §10 browser tidak ada | 7 Step 8 |
| §10 screenshot 0 | 11, 12 |
| §10 landscape/tablet | 8 (`object-fit: cover; object-position: top`) |
| §10 screenshot <400px | **gap — lihat di bawah** |
| §10 logo berlatar putih | 8 (`isLightBackedLogo`) |
| §10 grayscale fallback | 2 |
| §10 render timeout | 7 (`--virtual-time-budget=8000`) |
| §11 Test #1-#6 | 2, 2, 3, 4, 7, 10 |
| §12 invarian 1-10 | tersebar; #4 dikunci Test #5, #6 dikunci Test #1 |
| §13 perluasan | non-goal, tidak ada task |

**Gap ditemukan dan ditutup:** §10 mensyaratkan warning untuk screenshot dengan lebar
<400px. Ini tidak bisa masuk `validate.js` (tidak punya akses dimensi gambar sebelum
dimuat), jadi ditambahkan ke Task 8 sebagai langkah berikut:

- [ ] **Task 8, Step 2b: Tambahkan warning resolusi rendah ke `render.js`**

Di dalam `mount()`, tepat setelah `loadImage(order[0].src).then(function (heroImg) {`:

```javascript
      order.forEach(function (s, i) {
        var probe = new Image();
        probe.onload = function () {
          if (probe.naturalWidth < 400) {
            console.log('WARN screens[' + i + '] is only ' + probe.naturalWidth +
                        'px wide; it will look soft at scale 2');
          }
        };
        probe.src = s.src;
      });
```

Dan tambahkan assertion ke Task 10 Step 1, di dalam blok Test #6:

```bash
# Screenshot fixture 1080px, jadi tidak boleh ada warning resolusi.
if grep -q 'WARN screens' "$OUTDIR"/render-*.html 2>/dev/null; then
  echo "FAIL :: e2e unexpected low-resolution warning for 1080px fixture"; E2E_OK=0
fi
```

**2. Placeholder scan**

Tidak ada `TBD`/`TODO`/"implement later". Setiap langkah kode berisi kode sebenarnya.
Dua stub disengaja dan eksplisit dilabeli: `assets/js/render.js` di Task 7 Step 4 (ditandai
"Stub sementara, diisi penuh di Task 8" dan memang diganti seluruhnya di Task 8 Step 2),
dan `assets/cover.css` yang belum ada saat Task 7 (render script sudah menangani ketiadaannya
lewat `2>/dev/null ||` dan `if (Test-Path $coverCss)`).

**3. Type consistency**

- `CoverMaker.palette` → `rgbToHsl`, `extractHue`, `derive`, `oklchToLinearRgb`, `luminance`, `contrast`, `toCss`. Dipakai di Task 8 (`P.rgbToHsl`, `P.extractHue`, `P.derive`, `P.toCss`) dan Task 2 (`P.oklchToLinearRgb`, `P.contrast`). Cocok.
- `derive()` mengembalikan kunci `surfaceA`/`surfaceB` (camelCase); CSS custom property-nya `--surface-a`/`--surface-b` (kebab). Pemetaan dilakukan eksplisit di `resolvePalette` Task 8. Konsisten dengan `MANUAL_KEYS` di Task 3 yang juga camelCase.
- `validate()` mengembalikan `{data, warnings}`; dipakai begitu di Task 7 (halaman planner) dan Task 8 (`v.data`). Cocok.
- `renderSet(data)` menerima objek ternormalisasi ber-`screens`/`project`/`layout` — persis bentuk `v.data`. Cocok.
- `decor.resolve(setting, archetype)` dipanggil `NS.decor.resolve(data.decor, layout)` di Task 8. Cocok.
- Placeholder template `__STYLES__`, `__SCRIPTS__`, `__COVER_DATA__`, `__LAYOUT__`, `__SCALE__` — sama persis di Task 7 Step 1, Step 2 (awk), dan Step 3 (PowerShell `.Replace`). Cocok.
- Nama kelas CSS `.canvas`, `.decor`, `.stage`, `.phone`, `.phone__screen`, `.copy`, `.copy__name`, `.copy__rule`, `.copy__tagline`, `.copy__badges`, `.copy__meta`, `.copy__logo`, `.copy__logo--boxed` — didefinisikan Task 8, dipakai Task 8-9 dan dirujuk `references/layouts.md`. Cocok.
