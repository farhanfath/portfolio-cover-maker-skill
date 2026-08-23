(function (global) {
  var NS = global.CoverMaker = global.CoverMaker || {};

  var ELIGIBILITY = {
    'solo': 1,
    'duo': 2,
    'split-right': 2,
    'split-left': 2,
    'centered': 3,
    'diagonal': 3,
    'scatter': 5
  };

  // Urutan pengisian render set setelah pilihan auto.
  var PRIORITY = ['split-right', 'split-left', 'diagonal', 'centered', 'scatter', 'duo', 'solo'];

  var MAX_SET = 4;

  function eligible(n) {
    return PRIORITY.filter(function (a) { return n >= ELIGIBILITY[a]; });
  }

  // 'diagonal' sengaja tidak punya cabang di sini: ia arketipe pilihan, bukan
  // default - masuk ke render set lewat PRIORITY supaya user tetap melihatnya.
  function autoLayout(data) {
    var n = data.screens.length;
    var name = data.project.name || '';
    var tagline = data.project.tagline || '';
    if (n < 2) return 'solo';
    if (n === 2) return 'duo';
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
