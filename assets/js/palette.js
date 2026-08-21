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
