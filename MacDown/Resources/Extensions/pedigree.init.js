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
    draw(holder, source, index);
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
