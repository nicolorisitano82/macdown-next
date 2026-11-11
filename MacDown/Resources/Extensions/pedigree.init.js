// Pedigree bootstrap.
//
// A ```pedigree fence holds a clinical genetic pedigree written in the
// pedigree DSL (NSGC symbols); pedigree.js (pedigree-dsl, window.Pedigree)
// lays it out and draws it as SVG. A ```mermaid block that starts with
// `pedigree` is drawn too: mermaid.init.js registers the same library as a
// mermaid diagram type.
//
// Same rules as the mermaid and Graphviz bootstraps: re-callable as
// MacDownRenderPedigree() because a refresh replaces the body and runs no
// scripts; each drawing in a .macdown-diagram container, in document order,
// so the export can harvest it; colours follow the system appearance.
//
// Edit mode: each drawing has an "✎ Edit" button. The library's visual editor
// opens in place of the drawing (in a container of its own: the zoom owns
// clicks and drags on the drawing's), and on Done the new source goes to
// MacDown through the macdownPedigreeEdit message, with the block's position
// in the document (data-src, a UTF-8 offset) and the source it started from,
// so MacDown can check it is replacing what was edited. Only ```pedigree
// fences: a mermaid block is mermaid's.
//
// Written in ES5 on purpose, to match the rest of the bundled extensions.

(function () {

  var darkQuery = window.matchMedia
    ? window.matchMedia("(prefers-color-scheme: dark)")
    : null;

  var LAYOUT_WIDTH = 1000;

  // Labels, key and automatic notes follow the page language, else the
  // system's; a diagram can still force one with its own `lang` line.
  function language() {
    var l = (document.documentElement.getAttribute("lang")
      || navigator.language || "en").toLowerCase();
    return l.indexOf("it") === 0 ? "it" : "en";
  }

  function opaque(colour) {
    return colour && colour !== "transparent"
      && !/rgba\([^)]*,\s*0\)$/.test(colour);
  }

  // 0 (black) .. 1 (white); -1 when the colour cannot be read.
  function lightness(colour) {
    var m = /rgba?\((\d+),\s*(\d+),\s*(\d+)/.exec(colour || "");
    if (!m)
      return -1;
    return (0.299 * m[1] + 0.587 * m[2] + 0.114 * m[3]) / 255;
  }

  // A light drawing in the middle of a dark page is what this avoids: in
  // dark mode the pedigree takes the page's own text and background colours.
  function theme() {
    if (!(darkQuery && darkQuery.matches))
      return undefined;
    var page = window.getComputedStyle(document.body);
    // A style without dark rules leaves dark text on the dark page: then the
    // drawing picks its own light ink rather than the page's.
    var ink = lightness(page.color) > 0.5 ? page.color : "#e6e6e6";
    var paper = opaque(page.backgroundColor)
      && lightness(page.backgroundColor) < 0.5 ? page.backgroundColor : "#1e1e1e";
    return {
      ink: ink,
      paper: paper,
      muted: "#9a9a9a",
      border: "#666666"
    };
  }

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

  function renderOne(block, index) {
    var source = block.innerText || block.textContent;
    var holder = containerFor(block);
    if (!holder)
      return;
    // Kept for redrawing when the appearance changes: by then the fence is gone.
    holder.macdownPedigreeSource = source;
    holder.setAttribute("data-pedigree", String(index));
    // Where the fence starts in the document: hoedown puts it on the <div>
    // around the <pre> the holder replaced.
    var wrapper = holder.parentNode;
    if (wrapper && wrapper.getAttribute && wrapper.getAttribute("data-src") !== null)
      holder.setAttribute("data-pedigree-src", wrapper.getAttribute("data-src"));
    draw(holder, source, index);
  }

  /* ---------------------------------------------------------------- edit */

  var STYLE_ID = "macdown-pedigree-edit-style";
  function injectStyle() {
    if (document.getElementById(STYLE_ID))
      return;
    var style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent =
      ".macdown-pedigree-edit{position:absolute;top:6px;left:6px;z-index:3;"
      + "font:12px -apple-system,system-ui,sans-serif;padding:3px 9px;"
      + "border:1px solid rgba(128,128,128,.5);border-radius:6px;"
      + "background:rgba(255,255,255,.92);color:#1b1f24;cursor:pointer;"
      + "opacity:0;transition:opacity .15s ease-in-out}"
      + ".macdown-diagram:hover .macdown-pedigree-edit,"
      + ".macdown-pedigree-edit:focus{opacity:1}"
      + ".macdown-pedigree-editing{margin:1em 0}";
    document.head.appendChild(style);
  }

  function canSendEdits() {
    return !!(window.webkit && window.webkit.messageHandlers
      && window.webkit.messageHandlers.macdownPedigreeEdit);
  }

  function addEditButton(holder, source, index) {
    if (!canSendEdits() || !holder.getAttribute("data-pedigree-src")
        || typeof Pedigree.attachEditor !== "function")
      return;
    injectStyle();
    var button = document.createElement("button");
    button.type = "button";
    button.className = "macdown-pedigree-edit";
    button.textContent = language() === "it" ? "\u270E Modifica" : "\u270E Edit";
    // The zoom pans on mousedown and refits on double-click: keep both away.
    button.addEventListener("mousedown", function (e) { e.stopPropagation(); });
    button.addEventListener("dblclick", function (e) { e.stopPropagation(); });
    button.addEventListener("click", function (e) {
      e.stopPropagation();
      e.preventDefault();
      openEditor(holder, source, index);
    });
    holder.appendChild(button);
  }

  function openEditor(holder, source, index) {
    var host = document.createElement("div");
    host.className = "macdown-pedigree-editing";
    host.pedigreeSource = source;
    host.pedigreeOptions = { lang: language() };
    host.dataset.processed = "true";
    holder.parentNode.replaceChild(host, holder);

    var editor = Pedigree.attachEditor(host);
    host.addEventListener("pedigree:rendered", function (e) {
      // The editor's Done: it has just drawn the result into the host.
      var edited = e.detail && e.detail.source;
      var fresh = document.createElement("div");
      fresh.className = "macdown-diagram";
      fresh.setAttribute("data-pedigree", String(index));
      fresh.setAttribute("data-pedigree-src", holder.getAttribute("data-pedigree-src"));
      fresh.macdownPedigreeSource = edited || source;
      if (host.parentNode)
        host.parentNode.replaceChild(fresh, host);
      draw(fresh, fresh.macdownPedigreeSource, index);
      if (edited && edited.replace(/\s+$/, "") !== source.replace(/\s+$/, "")) {
        window.webkit.messageHandlers.macdownPedigreeEdit.postMessage({
          src: Number(holder.getAttribute("data-pedigree-src")),
          original: source,
          source: edited
        });
      }
    }, { once: true });
    editor.open();
  }

  function draw(holder, source, index) {
    holder.className = "macdown-diagram";
    holder.style.height = "";
    // A pedigree being typed is malformed most of the time; the parser says
    // where (line and column), which is worth more than a blank space.
    try {
      var P = window.Pedigree;
      var model = P.parse(source);
      var laid = P.layout(model, { lang: language() });
      holder.innerHTML = P.render(laid,
        { idPrefix: "macdown-pedigree-" + index, theme: theme() });
      var svg = holder.querySelector("svg");
      if (svg && window.MacDownMakeZoomable)
        MacDownMakeZoomable(holder, svg, "pedigree" + index, LAYOUT_WIDTH);
      addEditButton(holder, source, index);
    } catch (e) {
      holder.className = "macdown-diagram macdown-diagram-error";
      holder.style.height = "";
      holder.textContent = String(e && e.message ? e.message : e);
    }
  }

  function renderAll() {
    if (typeof window.Pedigree === "undefined")
      return;

    var blocks = document.querySelectorAll("code.language-pedigree");
    for (var i = 0; i < blocks.length; i++)
      renderOne(blocks[i], i);

    if (blocks.length && window.MacDownHarvest)
      MacDownHarvest();
  }

  window.MacDownRenderPedigree = renderAll;

  if (darkQuery) {
    var onSchemeChange = function () {
      var drawn = document.querySelectorAll(".macdown-diagram[data-pedigree]");
      for (var i = 0; i < drawn.length; i++) {
        if (drawn[i].macdownPedigreeSource)
          draw(drawn[i], drawn[i].macdownPedigreeSource,
               Number(drawn[i].getAttribute("data-pedigree")));
      }
      renderAll();
    };
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
