---
title: The guide
description: Every feature of MacDown Next, what it does, and what it deliberately does not do.
---

[← MacDown Next](./)

# The guide

A Markdown editor for macOS 26, released under the MIT licence. It is a fork
of [MacDown](https://github.com/MacDownApp/macdown) by Tzu-ping Chung, which
took its idea from [Mou](http://mouapp.com), brought up to macOS 26 and
extended around the three things the original left thin: **an editor that
showed you the punctuation rather than what it meant**, **diagrams that did
not draw**, and **getting a document out of the app in a shape someone else
can open**.

[**Download the latest release**](https://github.com/nicolorisitano82/macdown-next/releases/latest)
· [source](https://github.com/nicolorisitano82/macdown-next)
· [report something](https://github.com/nicolorisitano82/macdown-next/issues)

![The editor and the preview side by side](assets/screenshot.png)

Every feature, where it lives, and — where it matters — what it
deliberately does not do.

---

## Contents

- [Installing](#installing)
- [The editor](#the-editor)
- [Writing modes](#writing-modes)
- [The preview](#the-preview)
- [Diagrams and maths](#diagrams-and-maths)
- [Moving around a folder](#moving-around-a-folder)
- [Comparing two documents](#comparing-two-documents)
- [The prose checker](#the-prose-checker)
- [Writing help that runs on your Mac](#writing-help-that-runs-on-your-mac)
- [Collecting: saving a web page](#collecting-saving-a-web-page)
- [Exporting](#exporting)
- [In the Finder: Quick Look](#in-the-finder-quick-look)
- [Plug-ins](#plug-ins)
- [Keeping it up to date](#keeping-it-up-to-date)
- [Preferences, pane by pane](#preferences-pane-by-pane)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [The command line](#the-command-line)
- [A folder an assistant can read](#a-folder-an-assistant-can-read)
- [When the file changes underneath](#when-the-file-changes-underneath)
- [When something does not work](#when-something-does-not-work)
- [What leaves your Mac](#what-leaves-your-mac)
- [Building from source](#building-from-source)
- [Credits and licence](#credits-and-licence)

---

## Installing

Builds are on the
[releases page](https://github.com/nicolorisitano82/macdown-next/releases).
**macOS 26 or later** is required.

They are **not signed or notarised** — no Developer ID certificate stands
behind them — so macOS refuses one on a double-click. After dragging the
app to Applications, either right-click it and choose **Open** once, or run:

```
xattr -d com.apple.quarantine "/Applications/MacDown Next.app"
```

Whether to run an unsigned binary from the internet is your call;
[building from source](#building-from-source) is the alternative.

---

## The editor

The editor stops showing you the markup and starts drawing what it means.
**None of it touches the file**: what you save is the string you typed, to
the character. Everything in this section can be switched off in
**Preferences › Rendering › Writing**.

### What you see instead of markup

- **The markers disappear** until the caret reaches them — emphasis, bold,
  inline code, links, the hashes on a heading, the `>` on a quotation. They
  collapse the moment a construct is finished and come back the moment you
  work on it again.
- **Blocks are laid out**: lists get a hanging indent, quotations get a rule
  down the margin, headings get room above them, and three dashes are drawn
  as a line across the page.
- **Semantic styling**: headings are larger, emphasis is italic, code is
  monospaced — the text view draws the meaning while the file keeps the
  source.

### Text commands

| What | How |
|---|---|
| Bold, italic, underline | ⌘B, ⌘I, ⌘U |
| Strikethrough, highlight | ⌘-, ⌘= |
| Inline code | ⌘K |
| Fenced code block, with a language | ⌥⌘K |
| Heading levels 1–6, back to paragraph | ⌘1 … ⌘6, ⌘0 |
| Ordered list, unordered list, quotation | ⇧⌘O, ⇧⌘U, ⇧⌘B |
| Indent, outdent | ⌘], ⌘[ |
| Comment out | ⌘/ |
| Link, image | ⇧⌘K, ⇧⌘I |

- **⌘B and ⌘I act on the word under the caret** when nothing is selected,
  and take the markup off again if it is already there.
- **⇧⌘K asks where the link goes**: a web address you type or paste, or a
  file you find by browsing. A file inside the document's folder is written
  as a relative path, so the two keep working when you move them together.
- **The code button asks which kind**: backticks inside the line, or a
  fenced block marked with a language chosen from a list — and the list holds
  only the **113 languages this build can actually highlight**, not every
  language that exists.
- **Right-click inside a code block to lay it out** the way its language
  wants: brackets for the C family and JSON, tags for HTML, and for Python,
  YAML or a Makefile — where the indentation *is* the syntax — the step
  only, never the structure. A comment that runs over several lines moves
  whole, so its column of asterisks holds; multi-line strings and code that
  is aligned rather than indented are left alone.

### Tables

Tables are **edited by command, not by hand**: right-click one for rows and
columns, for moving a row up or down and a column left or right, for a
column's alignment, or for a repair of its dashes row. Moving is offered
only where there is somewhere to move to — the header stays the header and
the separator stays under it — and a column takes its alignment with it.

**Copy Table As** hands the whole thing to something that is not Markdown:
tab-separated for a spreadsheet, comma-separated for a form, or HTML for a
page, with the header as `<th>` and the fields quoted or escaped as each
format requires. It is the one table command that only reads.

The editor shows the source; the columns are drawn in the preview, which has
the room for them. Click a cell in the preview and the caret goes to that
cell.

### Closer to CommonMark and GitHub

- A hash with no space after it is a **hashtag, not a heading** — `#riunione`
  stays a tag, and `## Titolo` is the heading. The editor's parser and the
  renderer agree about this, so a line is never coloured as a heading in one
  pane and drawn as a paragraph in the other.
- `1)` numbers a list as `1.` does, and a list that starts at five is
  numbered from five.
- A backslash at the end of a line breaks it.
- A task marker is accepted in either case: `- [x]` and `- [X]`.

### Pasting

- **Pasting formatted text produces Markdown** — headings, nested lists,
  links, images, fenced code with its language, quotations, tables. What the
  converter does not recognise contributes its text and nothing else.
- **⌘⇧V pastes exactly what was copied**, when that is what you want.

### Small things that add up

- Deleting at the start of a heading's text demotes it to a paragraph; at
  the start of a quoted line it unquotes the line.
- **One window, one tab per open file**, using the system's own tabs — ⇧⌘\
  shows the overview, tabs drag between windows, and a link to a file that is
  already open goes to the tab it is open in rather than opening it twice.
- **Link to a file that does not exist yet**: select the words the link
  should say, right-click, and there is an empty Markdown file beside the
  document, linked, open in its own tab, named after the selection.
- **Document templates written by hand**, not generated: a commissioning
  report, a software test plan, release notes, minutes. Instant, the same
  every time. Put your own in the Templates folder and they appear in the
  menu.

---

## Writing modes

- **Read only** (⌥⌘L): a lock in the title bar, the text still selectable,
  and the commands that edit refused — the text view turns down what is
  typed into it but not what is done to it, so ⌘B would otherwise still put
  asterisks in a document that says it cannot change. Per window, and not
  remembered between launches.
- **Focus mode** (⌃⌥⌘F): everything but the paragraph you are writing is
  dimmed. The dimming is drawing and not text — it goes through the layout
  manager's temporary attributes — so it cannot reach the file.
- **Typewriter scrolling** (⌃⌥⌘T): the line you are writing is kept two
  fifths down the window instead of walking to the bottom.
- **Move completed tasks to the end** of the list the caret is in, **on
  command rather than by itself** — a list is often in the order it is in on
  purpose. An item takes its continuation lines and its nested tasks with it.
- **Word count, characters and reading time** under the window title.
  Reading time is two hundred words a minute: a figure, not a measurement,
  and what it is for is telling a page from a chapter.

---

## The preview

- **Dark mode**, following the system.
- **Typing does not make the preview flash**: it updates without reloading
  the page.
- **The two panes point at the same place.** Put the caret in a paragraph
  and a rule marks it in the preview; select in the preview and a rule marks
  it in the editor's margin. Scrolling is synchronised.
- **Text selected in the preview is selected in the editor.** Pick the words
  out of the rendered page, and when you let go of the mouse the same words
  are selected in the source with the focus there: delete removes them,
  typing replaces them. A selection made **with the keyboard** — ⇧ and the
  arrows, ⌘A — is followed as soon as it stops changing, and so is a drag
  that ends outside the page where no mouse release ever reaches it; in
  neither case does the focus move, since somebody still holding shift is
  not finished. Pressing delete on a selection made in the preview takes
  those words out of the source, focus and all. What you picked **stays
  marked in the preview** —
  the focus has gone to the editor, where the page's own selection would be
  dimmed or gone — until the next time you press the mouse in the page. The words are looked for inside the block they came
  from — and *which* "test" of that paragraph, since the page says how much
  of its own text came before the selection; a selection that
  crosses an emphasis takes the asterisks with it, since that is what the
  source says; and what the renderer changed on the way out is undone on the
  way back — `“così”` finds `"così"`, `l’editor` finds `l'editor`, `10–12`
  finds `10--12`, `&` finds `&amp;`. A selection that cannot be placed with
  certainty leaves the editor alone rather than selecting nearly the right
  thing — and says so where you are looking, by leaving the words marked in
  the preview with a dotted line instead of the filled one. A selection over
  several paragraphs is searched for across all of them, not only the one it
  began in. Switch it
  off in *Rendering* if the preview should stay a page to read. It works **both ways**: select a sentence in the editor
  and the same words are marked in the page, so you can see which paragraph
  you are about to change. What you wrote is `**grassetto**` and what the
  page shows is `grassetto`, so what goes across is the text as the page
  would show it — the markers that became formatting, the address of a
  link, the bullet of a list, all taken off first.
- **A sidebar with the document outline** (⌥⌘S), for moving around a long
  file.
- **Seven styles** for the rendered page and **fifteen editor themes**, all
  in the preferences.
- **Resting the pointer on a link for five seconds** opens a small card
  saying what is on the other side: the title and first lines of a
  neighbouring document, the picture itself if the link is an image, or a
  note that the file is not there yet. Five seconds is long on purpose — a
  card that appears while the pointer is merely crossing the page is a card
  in the way.
- For a **web address** the card takes the address apart — host, path,
  scheme — and fetches nothing. Switch on **Preferences › Rendering ›
  Writing › "Ask a web page what it is when the pointer rests on its link"**
  and it asks the page instead, showing its title and the summary the page
  writes for exactly this purpose. One request, four seconds at the outside,
  half a megabyte at the most, and only for the link under the pointer.
- **⌘R re-renders**, and the panes can be hidden with ⇧⌘H (preview) and ⇧⌘E
  (editor); ⌘0 puts them back to one to one.

---

## Diagrams and maths

- **Mermaid 11.17**, up from the 8.4.3 the original shipped: flowcharts,
  sequence diagrams, gantt charts, state and class diagrams, and the newer
  types 8.x never had.
- **Graphviz works**, with six layout engines — `dot`, `neato`, `fdp`,
  `circo`, `twopi`, `osage` — each its own fence language. (Its bundled
  script used to replace the whole page body with the first graph it drew.)
- **Zoom and pan on any diagram**: pinch or ⌃-scroll to magnify, drag to
  pan, double-click to fit again. The zoom survives a refresh, so you keep
  your place while typing.
- Diagrams **follow the appearance**, dark or light, and are **on by
  default** — the libraries are only loaded for documents that use them.
- **A maths editor for TeX** (⌃⌘M) with a live preview, backed by a bundled
  **MathJax**, so formulas render with no network.

---

## Working with Claude and other agents

- **Send to Claude / Send to ChatGPT** (File menu): the document — or the
  selection, if there is one — goes on the clipboard and a new chat opens
  with the prompt field **filled in, not sent**. What to ask is yours to
  write. With Claude's desktop application installed it opens there; without
  it, the web opens and the clipboard carries the text.
- **Instruction Files…** (⌃⌥⌘I): what an agent would actually read for the
  document in front of you.
  - The **hierarchy**, in load order: the machine's
    (`/Library/Application Support/ClaudeCode/CLAUDE.md`), yours
    (`~/.claude/CLAUDE.md`), then every `CLAUDE.md` and `.claude/CLAUDE.md`
    from the top of the tree down to the document's own folder, each
    followed by its `CLAUDE.local.md`. Files that are not there are listed
    too — where one *would* be read from is half the question — and clicking
    one makes it and opens it.
  - The **imports**: every `@path` resolved, as a tree, relative to the file
    that wrote it. Paths inside backticks are left alone, exactly as the
    loader leaves them.
  - What is **wrong**: an import that leads nowhere, one that closes a
    circle, one past the fourth hop where the loader stops reading, a file
    over two hundred lines or over the four mebibytes at which it is skipped
    altogether, and an `AGENTS.md` that nothing imports — Claude Code reads
    `CLAUDE.md`, so a lone `AGENTS.md` is a file nobody reads.

## Moving around a folder

- **WikiLinks**: `[[Another note]]` links to a neighbouring document, and
  says so when the file is not there.
- **Which documents point at this one** (⌃⌥⌘B): the folder is read and every
  citation listed with its line and the sentence around it, `[[wiki]]` and
  `[relative](links.md)` alike. Clicking one opens that document at that
  line. A link says where it goes and nothing said what points here, so this
  question used to be a `grep`.

---

## Comparing two documents

**File ▸ Compare with…** (⌃⌥⌘D) puts the document beside another one and
marks what differs. The left side is **what is in the editor**, not what is
on the disk — the question *what did I change* is asked before saving at
least as often as after — and the window says so when the two are not the
same thing.

- A line that was **changed** is one row with both versions on it, not a
  removal followed by an addition, and inside that row the **words** that
  actually differ are marked: a comma should not look like a rewritten
  paragraph.
- What was **added** is green, what was **taken away** is red, and the empty
  half of a row that only one side has is grey — the two columns stay level
  with each other all the way down, and each keeps its own line numbers.
- **Next** and **Previous** walk the differences; **Differences only** folds
  away what is the same, keeping three lines around each change; **Swap
  Sides** turns the comparison round; **Read the Files Again** compares the
  files as they are now, which is the button for *somebody else has just
  saved this*.
- The two sides scroll together.

With no document open the same menu item asks for two files instead.

---

## The prose checker

Qualifiers, weasel words, hedging, wordiness, passive tells and repeated
words, in **English and Italian**. The word lists are a resource file,
editable without rebuilding.

- The tally sits under the window title; **⌃⌥⌘H** turns the underlines on
  and off.
- **⌃⌥⌘P lists what it counted**: every flagged word with its line, and
  clicking one goes to it.
- One finding is not about words at all: a heading whose hashes are stuck to
  its text (`##Titolo`). That one has a single obvious answer, so its row
  carries a **Correggi** button that puts the space in. The rest are matters
  of judgement and get no button — a panel that offers to rewrite somebody's
  prose is a panel that will.
- Matches inside code, link destinations and raw HTML are dropped: none of
  those are prose.

---

## Writing help that runs on your Mac

Improve, correct, make formal, make plain, shorter, longer — over the
selection, or the paragraph the caret is in. The answer streams in and **one
undo takes it all back**.

**Nothing is sent anywhere.** A GGUF model runs locally through llama.cpp,
and the **Models panel** downloads and installs one without any other tool —
from a short curated list, or from any address you paste. The whole feature
can be switched off in the preferences, in which case the commands go away
and the Models panel stays, so a model already downloaded is still yours to
manage or delete.

---

## Collecting: saving a web page

**File › Save a Web Page as Markdown…** takes an address — the one on the
clipboard, if there is one — and writes the page as a Markdown file.

- The file goes **beside the document**, with the address and the date at the
  top as front matter: a clipping without its source is a quotation without
  a source. It is **linked where the caret was** and opened in a tab.
- From an **unsaved document** it opens as a document of its own, to be saved
  wherever you like — a page worth keeping is worth keeping before the notes
  it belongs to have a name.
- **What surrounds the page is left behind**: scripts, styles, navigation,
  headers, footers, asides. If the page says which part is the article
  (`<article>`, `<main>`), that part is taken.
- **Addresses are made absolute** against the page they came from, so its
  pictures and links still point somewhere once the text is a file in your
  folder.
- Headings are kept on one line even when the page wraps them in a
  paragraph, emphasis does not keep its padding inside the marks, and list
  items with nothing in them — share buttons, mostly — are dropped. The
  clipping is meant to be a file the renderer can read back.
- The conversion is the one used for pasting, so what arrives is what
  copying the page would have given.

---

## Exporting

| Format | Notes |
|---|---|
| **HTML** (⌥⌘E) | Styles and highlighting optional, chosen in the panel |
| **PDF** (⌥⌘P) | Through the print system; page setup is ⇧⌘P and printing ⌘P |
| **Word (.docx)** | Repaired after AppKit writes it — see below |
| **OpenDocument (.odt)** | Tables and styling survive AppKit's writer; the pictures it drops are put back |
| **Rich Text (.rtf)** | One file, pictures included — Cocoa only writes them into RTFD, so they are planted as `\pict` |
| **EPUB 3.3** | Images copied into the package, table of contents from the headings |
| **Textbundle** | The Markdown as written, with its pictures — a folder Finder shows as one item; **read as well as written** |
| **Textpack** | The same, zipped: what travels through mail; opening one unpacks it |
| **Copy HTML** (⌥⌘C) | The rendered page on the clipboard |

- **Word that survives the trip.** AppKit's own writer drops pictures,
  flattens tables into tab-separated paragraphs, loses list indentation and
  code block shading, and names a Mac-only font with nothing to substitute
  it. Each of those is repaired in the file afterwards, so tables arrive as
  tables and code arrives monospaced on Windows too.
- **Textbundle and Textpack keep the Markdown Markdown.** Every other
  export here goes through the rendered page; these two carry the source as
  written, with the links to local pictures pointed at `assets/`. It is
  [somebody else's format](http://textbundle.org) on purpose — Bear,
  Ulysses, iA Writer and Marked read it — and what comes out still works
  taken apart by hand: the Markdown is Markdown, the pictures are files, the
  links between them are relative, and nothing has to read `info.json` to
  make sense of it. A picture used from two folders keeps both, numbered; a
  picture kept on the web stays an address, and the export says which ones.
  A textbundle holds one text, so links to neighbouring documents are left
  as they are written.
- **Both open, too.** Double-click a `.textbundle` and the text inside it
  opens, named after the bundle rather than after `text.markdown`: the
  pictures under `assets/` resolve, saving writes back into the bundle, and
  the rest of the application never has to know it is looking at a
  container. A `.textpack` is unpacked next to itself first — into
  `<name>.textbundle`, numbered if that name is taken — because a document
  opened out of a temporary folder is a document whose next save goes
  somewhere nobody will look again. An archive naming a path of its own
  (`../somewhere`) is refused whole rather than partly unpacked.
- **Pictures kept on the web travel too.** A .docx and an EPUB are packages,
  so a picture they do not carry is a picture nobody sees. Both exports
  fetch the remote ones first, with a sheet while they wait and a count of
  whatever could not be had. Switch it off in the preferences if an export
  must make no network requests.
- **Diagrams are drawn into every export** — HTML, Word, OpenDocument, RTF
  and EPUB alike — rather than shipping the source and a library and hoping
  the reader runs JavaScript.
- **A plug-in can add a format of its own.** Adopt `MPExporterPlugIn` — a
  name, an extension, and one method that turns the rendered document into
  bytes — and it appears in File ▸ Export beside the built-in ones. What
  arrives is the document already made self-contained: diagrams and formulas
  drawn as pictures, remote pictures fetched if the preferences allow it.
  Exporters stay **out of the plug-ins menu**, which lists commands; they are
  still listed in the plug-ins window, and switching one off takes its format
  out of the Export menu.

---

## In the Finder: Quick Look

Press space on a `.md` file and Finder shows **the document as it reads** —
headings, tables, code, to-do boxes — with the same style sheet the
application opens with, instead of the source.

- Pictures kept beside the document **travel with the preview**, because the
  page Quick Look draws has no access to the disk.
- That page **cannot reach the network**: a document that asks for a remote
  image does not get one, and no script in it runs. Selecting a file in
  Finder is enough to draw the preview, which is the right perimeter for
  something that starts by itself.
- Front matter is left out, and a document longer than two megabytes is
  shown up to that point, saying so.
- **Diagrams and formulas are drawn**, not shown as source: mermaid, all
  six Graphviz engines, and TeX through MathJax. The page has no scripts in
  it, so the extension draws them in a web view of its own and puts finished
  SVG in the page — up to forty of them, with two and a half seconds for all
  together, and only the libraries a document actually needs are loaded.
  Anything that does not draw in time, or at all, keeps its source. The
  extension carries the network entitlement for this — WebKit will not
  finish a load without it, even for a page built in memory — and makes no
  request with it: the libraries are read from the bundle, and the page
  Finder gets still forbids the network.
- **WikiLinks are links**: `[[Target]]` and `[[Target|label]]` resolve
  against the document's folder — the name as written, then `.md`,
  `.markdown`, `.txt` — and a target that is not there yet is marked, as it
  is in the editor. Nothing navigates from a preview; a document should
  simply read the same closed as open.
- What counts as a formula is **the application's own setting**: `$$…$$`
  always, and a single `$…$` only when *Rendering › TeX-like math syntax* is
  on, because otherwise "costs $5 and $7" reads as algebra. The extension
  reads those two preferences, read-only, and nothing else.

**Preferences › Quick Look** says where that preview stands and does
something about it: whether macOS has it, which copy of the application is
providing it, and which version — with **Install**, **Update** when the
registered build is older than the one in hand, and **Remove**. It is worth
a panel because the registration goes wrong quietly: a copy left in the
Downloads folder can hold it, and a preview that does not appear says
nothing at all.

---

## Plug-ins

Plug-ins are bundles inside `Contents/PlugIns` of the application, or in
`~/Library/Application Support/MacDown Next/PlugIns`. They are listed in the
plug-ins window, where each can be switched off; one dropped into the folder
works without being turned on first.

### The draw.io importer

Ships with the application (`Drawio.plugin`) and needs no installing. Pick a
`.drawio` file and **every page in it becomes a PNG beside the document**,
linked where the caret is.

- Drawn by **draw.io's own viewer and its 97 shape libraries** — AWS, Cisco,
  Azure, GCP, BPMN, Kubernetes and the rest — all of which travel inside the
  plug-in: 23 MB of XML stored as 3.
- Every address the viewer would reach on the network points back into the
  bundle instead, so **nothing is sent and nothing is fetched**: it draws
  with no connection at all. An export server of your own can be used
  instead, if you would rather.
- All four shapes a diagram arrives in are read: plain XML, the
  deflate+base64 form draw.io actually saves, editable PNG and editable SVG.
- Re-importing **rewrites** the files instead of adding a second link, which
  is how a figure in a report gets updated.
- Progress is shown while it works, and if something fails the log can be
  read and exported.

---

## Keeping it up to date

**MacDown Next ▸ Check for Updates…**, and once a day on its own unless you
turn that off in **Preferences › Updates**. Four questions, in order:

1. **Is there a newer release?** A request to GitHub's list of releases. If
   there is nothing, it says nothing.
2. **Shall it be downloaded?** With the version, the first lines of the
   release notes, how big it is, and a button to open the notes in full.
3. **Here it is — shall the disk image be opened?** The download goes to
   **Downloads**, with a progress bar and a **Stop** that really stops it,
   and it will not overwrite a file already there.
4. **Yes** — the application opens the disk image and quits, and dragging the
   new copy into Applications stays yours to do.

**Nothing installs itself.** Replacing the running application from
underneath works ninety-nine times out of a hundred; the hundredth leaves a
bundle half written, and for an unsigned app there is no system updater to
put it right. The disk image is only ever fetched from GitHub — checked when
the list is read, and again before the download starts.

---

## Preferences, pane by pane

| Pane | What is in it |
|---|---|
| **General** | Untitled document on launch, creating a file for a link target |
| **Markdown** | The parser's extensions: tables, fenced code, footnotes, autolinking, strikethrough, underline, superscript, highlight, quotes, smart typography, intra-word emphasis, manual rendering |
| **Editor** | Font, theme, insets, line spacing, width limit, sync scrolling, tab conversion, auto-increment of numbered lists, matching characters, smart home, scrolling past the end, trailing newline, list marker, word count type |
| **Rendering** | The HTML style, syntax highlighting and its theme, line numbers, task lists, hard wrap, MathJax, Graphviz, Mermaid, front matter, wiki links, table of contents, whether selecting in one pane selects in the other — and the **Writing** switches for everything the editor draws |
| **Terminal** | The `macdownext` command line tool: install, uninstall, where it is |
| **Quick Look** | The Finder preview: state, version, Install / Update / Remove |
| **Agents** | The folder server: the switch, the folder and level to offer, the line to paste into a client, and what has been asked of it |
| **Updates** | Whether to look once a day, when it last looked, and a check now |

---

## Keyboard shortcuts

### Documents and panes

| Keys | What |
|---|---|
| ⌘N · ⌘O | New · Open |
| ⌘S · ⇧⌘S | Save · Save As |
| ⌘R | Render the preview again |
| ⌘0 | Editor and preview, one to one |
| ⇧⌘H · ⇧⌘E | Hide the preview · hide the editor |
| ⌥⌘S · ⌘T | Sidebar · toolbar |
| ⇧⌘\ | Tab overview |

### Writing

| Keys | What |
|---|---|
| ⌘B · ⌘I · ⌘U | Bold · italic · underline |
| ⌘- · ⌘= | Strikethrough · highlight |
| ⌘K · ⌥⌘K | Inline code · fenced code block |
| ⇧⌘K · ⇧⌘I | Link · image |
| ⌘1 – ⌘6 · ⌘0 | Heading levels · back to paragraph |
| ⇧⌘O · ⇧⌘U · ⇧⌘B | Ordered list · unordered list · quotation |
| ⌘] · ⌘[ | Indent · outdent |
| ⌘/ | Comment out |
| ⇧⌘V | Paste verbatim |
| ⌃⌘M | Maths editor |

### Reading, checking, moving

| Keys | What |
|---|---|
| ⌥⌘L | Read only |
| ⌃⌥⌘F · ⌃⌥⌘T | Focus mode · typewriter scrolling |
| ⌃⌥⌘H | Prose underlines on and off |
| ⌃⌥⌘P | List what the prose checker counted |
| ⌃⌥⌘B | Which documents link to this one |
| ⌃⌥⌘D | Compare this document with another |
| ⌥⌘C | Copy the rendered HTML |

### Exporting

| Keys | What |
|---|---|
| ⌥⌘E | HTML |
| ⌥⌘P | PDF |
| ⌘P · ⇧⌘P | Print · page setup |

---

## The command line

`macdownext` opens files from the terminal, and can be installed from
**Preferences › Terminal** — which also says where it went and takes it away
again.

```
macdownext note.md          # open a file
cat note.md | macdownext    # open what is piped in
```

---

## A folder an assistant can read

Inside the application there is a second command, `macdownext-mcp`: an
**MCP server** that hands one folder of Markdown to Claude Code, Claude
Desktop, or anything else that speaks the protocol. The client starts it,
talks to it over a pipe and stops it; MacDown Next does not have to be
running, because what the server reads is the folder.

As started above it does seven things and nothing else: **search** the
folder, **read** a file, **list** what is there, give a document's
**outline**, say who cites a document (**backlinks**), read a document's
YAML **frontmatter**, and find the documents that declare a field
(**find_by_field**). Nothing writes. Citations and front matter come from
the same code the editor runs, so a document cannot be cited in the
application and uncited over the wire. The folder is declared, never
guessed:

```bash
claude mcp add notes -- \
    "/Applications/MacDown Next.app/Contents/SharedSupport/bin/macdownext-mcp" \
    --root ~/Notes
```

For a client that reads a configuration file instead:

```json
{"mcpServers": {"notes": {
    "command": "/Applications/MacDown Next.app/Contents/SharedSupport/bin/macdownext-mcp",
    "args": ["--root", "/Users/you/Notes"]}}}
```

- **One folder.** A second `--root` is an error, not a second permission.
- **Nothing leaves it.** A `..`, an absolute path, a symbolic link pointing
  outside: refused, and the answer says so in words the assistant can pass
  on to you.
- **Text only**, and a file over 2 MB is refused with its size. A
  `.textbundle` counts as one document, not as a folder to walk into.
- `--exclude <glob>` leaves more out; `.git`, `node_modules`, `.build` and
  dot-files are left out already.

Without `--root` it does not start.

### Letting it write

Writing is off until you ask for it, and you ask at the level you mean:

```bash
macdownext-mcp --root ~/Notes            # reads, and that is all
macdownext-mcp --root ~/Notes --append   # and adds to the end of a document
macdownext-mcp --root ~/Notes --write    # and makes new ones, and replaces text
```

Two levels at once is an error, not the higher of the two — and the level
decides what the assistant is even offered: seven tools reading, eight with
`--append`, ten with `--write`.

- **append** adds to the end of a document that exists, with the line ending
  it was missing, and changes nothing that was already written.
- **create** makes a document that is not there. It refuses a path that is
  taken, and it makes no folders along the way.
- **replace** swaps text that is in the document for other text and says how
  many times and on which lines. If the text to find is not there it refuses:
  a change is never a guess.

What is not there, at any level: nothing deletes, nothing renames, nothing
writes a whole file over one that existed. Deleting is the Finder's job — it
has a Trash.

### What was asked, and what happened

Every call — reads, changes and refusals — is written to
`~/Library/Logs/MacDown Next/mcp.log`, with the time, the tool, the file and
how it went:

```
2026-09-11T20:03:16Z  create    ok       nuovo.md   20 bytes
2026-09-11T20:03:16Z  create    refused  nuovo.md   there is already a file at that path…
```

It answers the question that comes the day after — *who touched this file,
and when* — which the file itself cannot once it has been changed. It goes
nowhere: `--log <file>` puts it somewhere else, `--no-log` switches it off,
and past 2 MB it starts again. It is a different file from the editor's own
`actions.log`, which is a diagnostic recording you switch on.

### The panel

**Settings ▸ Agents** is where this is set up and watched:

- a **switch** — off, the server refuses to start and says so, whatever a
  client has in its configuration. It is the one thing about the server the
  application decides, and each copy of the application governs its own;
- the **folder** to offer and what it **may** do, which together build the
  line above — with the path of the server inside *this* copy of the
  application, and a button that copies it;
- **what has been asked of it**: the last two hundred lines of the log, with
  a way to show the file in the Finder or empty it.

Nothing here is a setting the server reads afterwards, apart from the
switch: the folder and the level travel in the line you paste, so what a
client may do is written in the client's own configuration where you can
read it.

The design, the measurements and what was deliberately left out are in
[the journal](docs/progetto-mcp.md).

---

## When the file changes underneath

Documents do not sit still any more: `git` checks out a branch, a script
rewrites a table, an agent saves over the file you have open. MacDown Next
notices.

- **With nothing of yours in hand it reloads** — quietly, keeping the caret
  where it was, and saying so in the action log. The alternative is showing
  a document that no longer exists and writing it back over the file on the
  next save.
- **With unsaved changes it asks once**: *Reload from the File* or *Keep
  What I Have*. Both sides have something the other has not, and that is
  not a decision an editor should take for you.
- **If the file has gone** — moved by something that does not coordinate,
  or deleted — it says so, with the path, and offers **Save As…**. Revert
  says the same rather than failing as a save, which is what macOS reports
  when the last saved version cannot be written back to a path that holds
  nothing.

A file that reads as nothing is not a file that changed: one being written
to at this instant reads empty for a moment, and answering "reload" to that
would empty the document.

### Saving, and getting work back

Nothing here invents a place to keep your work: macOS already has three,
and the application uses all three.

- **A document with a file saves into the file**, by itself, while you
  write. Measured by killing the process outright: the text typed twenty
  seconds earlier was already on disk.
- **A document with no file yet** is kept by the system in
  `~/Library/Autosave Information/` and comes back when the application is
  opened again — measured the same way.
- **Every version is kept**: File ▸ Revert To ▸ **Browse All Versions…** is
  the Time Machine view of that one file.

What was missing was a version *just before the machine rewrites your
words*, which is the change most likely to be regretted — and ⌘Z does not
survive closing the window. The writing commands, a prose fix and moving
done tasks to the end now save the document first, so the version browser
has a "before" to go back to. The bytes are taken before the rewrite
starts; the rewrite cannot get into the version.

## When something does not work

**Help › Record What I Do.** Off unless you switch it on, and then every
command and its answer goes into `~/Library/Logs/MacDown Next/actions.log` —
what a backlink search read, what a command answered. **Nothing leaves the
Mac**; the menu shows the file in the Finder and empties it. It exists
because the alternative was guessing at what somebody else's screen was
doing.

If the Finder preview does not appear, **Preferences › Quick Look** will
usually say why, and its **Install** or **Update** button is the answer.

Problems are best
[reported here](https://github.com/nicolorisitano82/macdown-next/issues) —
this fork's own tracker, not the original's.

---

## What leaves your Mac

Everything in the application works offline. These are the only things that
reach the network, all of them either asked for or switchable:

| What | When | Switch |
|---|---|---|
| The list of releases on GitHub | Once a day, and when you ask | Preferences › Updates |
| The disk image of an update | Only after you say yes | — |
| The page you are clipping | Only when you give it an address | — |
| Pictures kept on the web | While exporting to .docx or EPUB | Preferences |
| A language model you choose | While the Models panel downloads it | — |

Not on that list, on purpose: the writing help (the model runs on your Mac),
the diagrams (their libraries are inside the app), the maths (MathJax is
bundled), the draw.io plug-in (viewer and shapes are inside it), the link
cards in the preview (an address is taken apart, not visited), the Finder
preview (it cannot reach the network at all), and the action log.

`macdownext-mcp` touches no network either: it reads the folder, writes to a
pipe, and — when you start it with `--append` or `--write` — to the
documents you pointed it at and to its own log. What happens after that is the assistant's business — a client
that sends what it read to a model on the web is sending your documents
there, which is the reason the folder is declared one at a time.

---

## Building from source

```
git clone https://github.com/nicolorisitano82/macdown-next.git
cd macdown-next
git submodule update --init
pod install
make -C Dependency/peg-markdown-highlight
Tools/build_llama.sh
open MacDown.xcworkspace
```

Open the **workspace**, not the project: the project alone has no pods.
Xcode 26 or later is needed, for the macOS 26 SDK. `Tools/build_llama.sh`
needs `cmake` and takes about fifteen seconds.

There is also a control suite, which builds, runs the tests, then checks the
things a green test suite cannot see — the built product, the page Finder
would be handed, the real list of releases, and a real Quick Look preview:

```
Tools/verify_features.sh
```

---

## Credits and licence

MIT, like the MacDown it grew out of. The full text is in the `LICENSE`
directory, along with the licences of the third-party components, which are
also in the **About MacDown Next** panel.

It leans on [Hoedown](https://github.com/hoedown/hoedown) for the Markdown,
[Prism](https://prismjs.com) for code highlighting,
[PEG Markdown Highlight](https://github.com/ali-rantakari/peg-markdown-highlight)
for the editor's own, [mermaid](https://mermaid.js.org) and
[Graphviz](https://graphviz.org) through [Viz.js](https://github.com/mdaines/viz.js)
for the diagrams, [MathJax](https://www.mathjax.org) for the formulas,
[llama.cpp](https://github.com/ggml-org/llama.cpp) for the writing help, and
[draw.io](https://www.drawio.com)'s viewer for the importer. The editor
themes and several of the preview styles come from [Mou](http://mouapp.com),
courtesy of Chen Luo.

Journals of the work, in Italian, written for whoever picks a piece of this
up next: [the editor's text rendering](docs/wysiwyg-testo.md),
[the local writing help](docs/ai-locale.md),
[the two previews](docs/anteprime.md),
[the selection the two panes share](docs/selezione.md),
[where the work goes](docs/salvataggi.md),
[the MCP server over a folder](docs/progetto-mcp.md),
[the plan for syncing a folder](docs/progetto-sync.md),
[the updater](docs/aggiornamenti.md),
[the draw.io plug-in](docs/drawio.md),
[code blocks](docs/blocchi-codice.md), and
[what Bear does and what we took from it](docs/roadmap-bear.md).
