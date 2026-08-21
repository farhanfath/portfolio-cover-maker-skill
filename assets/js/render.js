// STUB — replaced wholesale in Task 8. Only exists here so the Task 7 render
// pipeline (template assembly + headless screenshot) has something to run.
(function (global) {
  document.getElementById('stage').textContent =
    'layout=' + global.COVER_LAYOUT + ' name=' + global.COVER_DATA.project.name;
})(window);
