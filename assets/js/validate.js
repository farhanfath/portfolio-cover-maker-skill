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
