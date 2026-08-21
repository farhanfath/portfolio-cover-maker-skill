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
      // Peringatan resolusi rendah: screenshot <400px lebar akan terlihat
      // lembek pada skala render 2x/3x. Probe async, terpisah dari alur
      // mount() utama supaya tidak menunda render.
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
