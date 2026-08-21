// GENERATED oleh scripts/build-assets.sh. Jangan diedit tangan.
(function (global) {
  var NS = global.CoverMaker = global.CoverMaker || {};
  var SHAPES = {
    brush: '<svg viewBox="0 0 800 900" preserveAspectRatio="none"><path fill="currentColor" d="M812 -20 C700 90 640 150 596 240 C548 338 560 392 512 470 C470 540 402 566 352 640 C300 716 296 800 240 920 L812 920 Z"/></svg>',
    blob: '<svg viewBox="0 0 1000 1000"><circle cx="500" cy="620" r="470" fill="currentColor"/></svg>',
    dots: '<svg viewBox="0 0 100 100"><defs><pattern id="cm-dots-d" width="12.5" height="12.5" patternUnits="userSpaceOnUse"><circle cx="2" cy="2" r="1.6" fill="currentColor"/></pattern></defs><rect width="100" height="100" fill="url(#cm-dots-d)"/></svg>',
    grid: '<svg viewBox="0 0 100 100"><defs><pattern id="cm-grid-g" width="20" height="20" patternUnits="userSpaceOnUse"><path d="M20 0 L0 0 0 20" fill="none" stroke="currentColor" stroke-width="0.7"/></pattern></defs><rect width="100" height="100" fill="url(#cm-grid-g)"/></svg>',
  };
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
