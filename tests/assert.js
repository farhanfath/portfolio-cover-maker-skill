// Runner assertion mini. Menulis baris PASS/FAIL ke #out supaya bisa dibaca --dump-dom.
(function (global) {
  var results = [];
  function record(pass, label, detail) {
    results.push((pass ? 'PASS' : 'FAIL') + ' :: ' + label + (detail ? ' :: ' + detail : ''));
  }
  function render() {
    var fails = results.filter(function (r) { return r.indexOf('FAIL') === 0; }).length;
    var el = document.getElementById('out');
    if (!el) return;
    el.textContent = results.join('\n') + '\nTOTAL ' + results.length + ' FAILED ' + fails;
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
    // Rendering now happens automatically on window 'load' (see below), so that
    // all <script> blocks appended by later tasks — which run before 'load'
    // fires — are reflected in the output. done() is kept for compatibility:
    // it is safe to call zero or more times, and always re-renders the full
    // set of results recorded so far.
    done: function () {
      render();
    }
  };
  global.Assert = Assert;
  global.addEventListener('load', render);
})(window);
