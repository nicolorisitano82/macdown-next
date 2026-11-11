// MacDown mermaid bootstrap.
//
// Three things make this different from a plain "render on load" script.
//
// First, the preview is refreshed by replacing the document's innerHTML.
// That does not re-execute <script> tags, so binding to the load event only
// ever rendered the first version of a document: every keystroke afterwards
// left the fences as bare code blocks. window.mermaid does survive the swap,
// so this exposes MacDownRenderMermaid() and MacDown calls it after each
// refresh instead.
//
// Second, the diagram theme has to follow the system appearance, otherwise a
// light diagram sits in the middle of a dark page.
//
// Third, a big diagram gets squeezed until its labels overlap, so each one is
// wrapped in the pan-and-zoom viewport from diagram-zoom.js.
//
// Written in ES5 on purpose, to match the rest of the bundled extensions.
// mermaid's render became asynchronous in version 10, and is driven here
// through .then rather than async/await for the same reason.

(function () {

  var darkQuery = window.matchMedia
    ? window.matchMedia("(prefers-color-scheme: dark)")
    : null;

  var counter = 0;

  // Zoom survives a refresh: you would otherwise lose your place in a large
  // diagram on every keystroke. Keyed by the diagram's position in the
  // document, which is stable as long as you are not adding fences above it.
  // Width mermaid is asked to lay a gantt out at. Its default axisFormat is
  // %Y-%m-%d, ten characters per tick, and at the width of a preview pane the
  // date axis collides with itself. Laying it out wide and then fitting it
  // keeps the labels apart; zoom is what makes them readable again.
  var GANTT_LAYOUT_WIDTH = 1600;

  function currentTheme() {
    return (darkQuery && darkQuery.matches) ? "dark" : "forest";
  }

  function configure() {
    mermaid.initialize({
      startOnLoad: false,
      theme: currentTheme(),
      flowchart: {
        htmlLabels: false,
        useMaxWidth: true
      },
      gantt: {
        useWidth: GANTT_LAYOUT_WIDTH
      }
    });
  }


  /* -------------------------------------------------------------- render */

  // The fence arrives as <pre><code class="language-mermaid">. Swapping the
  // <pre> out for a plain container drops the code block's frame and
  // background, which would otherwise box the finished diagram.
  function containerFor(block) {
    var target = block;
    if (block.tagName === "CODE"
        && block.parentElement
        && block.parentElement.tagName === "PRE") {
      target = block.parentElement;
    }
    if (!target.parentNode)
      return null;

    var holder = document.createElement("div");
    holder.className = "macdown-diagram";
    target.parentNode.replaceChild(holder, target);
    return holder;
  }

  // A mermaid block that starts with `pedigree` is a clinical pedigree: when
  // pedigree.js is on the page (it is loaded before mermaid when the pedigree
  // preference is on), it is registered as a mermaid diagram type. The
  // registration is asynchronous and happens once per page.
  var registering = null;
  function externalDiagramsReady() {
    if (registering)
      return registering;
    if (!window.Pedigree || !Pedigree.mermaidPlugin
        || typeof mermaid.registerExternalDiagrams !== "function")
      return null;
    try {
      registering = mermaid.registerExternalDiagrams([Pedigree.mermaidPlugin]);
    } catch (e) {
      registering = null;
    }
    return registering;
  }

  function renderAll() {
    if (typeof mermaid === "undefined")
      return;

    var blocks = document.querySelectorAll(".language-mermaid");
    if (!blocks.length)
      return;

    var ready = externalDiagramsReady();
    if (ready && typeof ready.then === "function") {
      // Rendering waits for the registration; a failed registration only
      // costs the pedigree blocks, which then show mermaid's own error.
      ready.then(renderBlocks, renderBlocks);
      return;
    }
    renderBlocks();
  }

  function renderBlocks() {
    var blocks = document.querySelectorAll(".language-mermaid");
    if (!blocks.length)
      return;

    configure();

    // The export harvests what the preview has drawn, and mermaid draws
    // asynchronously: without waiting, an export taken right after a load
    // finds code blocks where the diagrams will be.
    var outstanding = blocks.length;
    function oneFinished() {
      outstanding--;
      if (outstanding <= 0 && window.MacDownHarvest)
        MacDownHarvest();
    }

    for (var i = 0; i < blocks.length; i++) {
      renderOne(blocks[i], "d" + i, oneFinished);
    }
  }

  // A malformed diagram must not take the rest of the page down with it, and
  // while you are typing one it is malformed most of the time. Since mermaid
  // 10 the failure arrives as a rejected promise rather than a throw, so both
  // paths end up in the same handler.
  function renderOne(block, stateKey, done) {
    function finished() {
      if (typeof done === "function")
        done();
    }

    var source = block.innerText || block.textContent;
    var holder = containerFor(block);
    if (!holder) {
      finished();
      return;
    }

    var id = "macdown-mermaid-" + (counter++);

    function succeeded(result) {
      // mermaid 10 resolves to an object; older releases handed the string
      // to a callback. Accept either, so a downgrade does not go silent.
      var svgCode = (result && result.svg) ? result.svg : result;
      holder.innerHTML = svgCode;
      var svg = holder.querySelector("svg");
      if (svg && window.MacDownMakeZoomable)
        MacDownMakeZoomable(holder, svg, stateKey, GANTT_LAYOUT_WIDTH);
      finished();
    }

    function failed(e) {
      holder.className = "macdown-diagram macdown-diagram-error";
      holder.style.height = "";
      holder.textContent = String(e && e.message ? e.message : e);

      // mermaid leaves its scratch element behind when a render fails.
      var orphan = document.getElementById(id);
      if (orphan && orphan.parentNode)
        orphan.parentNode.removeChild(orphan);
      finished();
    }

    try {
      var outcome = mermaid.render(id, source);
      if (outcome && typeof outcome.then === "function")
        outcome.then(succeeded, failed);
      else
        succeeded(outcome);
    } catch (e) {
      failed(e);
    }
  }

  window.MacDownRenderMermaid = renderAll;

  if (darkQuery) {
    var onSchemeChange = function () { renderAll(); };
    if (darkQuery.addEventListener)
      darkQuery.addEventListener("change", onSchemeChange);
    else if (darkQuery.addListener)
      darkQuery.addListener(onSchemeChange);
  }

  if (document.readyState === "complete"
      || document.readyState === "interactive") {
    renderAll();
  } else {
    window.addEventListener("load", renderAll, false);
  }
})();
