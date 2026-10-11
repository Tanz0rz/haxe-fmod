// Exactly one example game exists at a time. The selected tab gets a fresh
// frame, and the frame of the tab left behind is removed, which unloads
// that game and its audio. Each game draws its own Play button.
(function () {
  var set = document.querySelector('.tabbed-set');
  if (!set || !set.querySelector('.example-game')) return;
  var inputs = Array.prototype.slice.call(set.querySelectorAll(':scope > input'));
  var blocks = Array.prototype.slice.call(set.querySelectorAll(':scope > .tabbed-content > .tabbed-block'));
  var current = null;

  function selectedSlot() {
    for (var i = 0; i < inputs.length; i++) {
      if (inputs[i].checked && blocks[i]) return blocks[i].querySelector('.example-game');
    }
    return blocks[0] && blocks[0].querySelector('.example-game');
  }

  function show() {
    var slot = selectedSlot();
    if (!slot || slot === current) return;
    if (current) current.replaceChildren();
    var frame = document.createElement('iframe');
    frame.src = '../games/' + slot.dataset.game + '/';
    frame.title = slot.dataset.title;
    frame.allow = 'autoplay';
    slot.replaceChildren(frame);
    current = slot;
  }

  inputs.forEach(function (input) {
    input.addEventListener('change', show);
  });
  // The theme can restore a remembered tab after this script runs
  window.addEventListener('load', show);
  show();
})();
