# MacDown Next

A Markdown editor for macOS, released under the MIT License.

This is a fork of [MacDown](https://github.com/MacDownApp/macdown) by
Tzu-ping Chung, who took the idea from [Chen Luo](https://twitter.com/chenluois)’s
[Mou](http://mouapp.com). It has been brought up to macOS 26 and extended,
around the three things the original left thin: an editor that showed you
the punctuation rather than what it meant, diagrams that did not draw, and
getting a document out of the app in a shape someone else can open.

## Screenshot

![screenshot](assets/screenshot.png)

## What this fork adds

### Diagrams

* **Mermaid 11.17**, up from the 8.4.3 the original shipped. Flowcharts,
  sequence diagrams, gantt charts, state and class diagrams, and the newer
  types 8.x never had.
* **Graphviz works.** Its bundled script used to replace the whole page body
  with the first graph it drew, taking the rest of the document with it, and
  it stopped redrawing after the first keystroke. Six layout engines —
  `dot`, `neato`, `fdp`, `circo`, `twopi`, `osage` — each its own fence
  language.
* **Zoom and pan on any diagram.** A wide gantt or a large graph is fitted
  to the pane and its labels collide; pinch or ⌃-scroll to magnify, drag to
  pan, double-click to fit again. The zoom survives a refresh, so you keep
  your place while typing.
* **Diagrams follow the appearance**, dark or light, and are **on by
  default** — the libraries are only loaded for documents that use them.

### Export

* **EPUB 3.3.** Images are copied into the package and the table of contents
  is built from the headings.
* **OpenDocument and RTF**, with the pictures AppKit's own writers drop put
  back: a `draw:frame` and a `Pictures/` entry for .odt, a `\pict` group for
  .rtf. Tables and character styling those two writers keep by themselves.
* **Textbundle and Textpack**, written *and* read. A `.textbundle` is a
  folder Finder shows as one item — `info.json`, `text.markdown`,
  `assets/` — and a `.textpack` is that folder zipped, which is what
  travels through mail; Bear, Ulysses, iA Writer and Marked read both. The
  two exports skip the rendered page, which every other export here goes
  through: what a textbundle holds is the Markdown *as written*, with the
  links to local pictures pointed at `assets/`, so what comes out still
  works taken apart by hand. Opening one opens the text inside it, named
  after the bundle, with the pictures resolving and saving writing back
  into it; opening a `.textpack` unpacks it next to itself first.
* **A plug-in can add a format.** `MPExporterPlugIn` is a name, an extension
  and one method; the format then sits in File ▸ Export with the others.
  Exporters do not appear in the plug-ins menu — that menu is for commands —
  but they are in the plug-ins window, and switching one off removes its
  format.
* **Pictures kept on the web travel too.** A .docx and an EPUB are packages,
  so a picture they do not carry is a picture nobody sees. Both exports fetch
  the remote ones first, with a sheet while they wait and a count of whatever
  could not be had. Turn it off in the preferences if an export must make no
  network requests.
* **Word (.docx) that survives the trip.** AppKit's own writer drops
  pictures, flattens tables into tab-separated paragraphs, loses list
  indentation and code block shading, and names a Mac-only font with nothing
  to substitute it. Each of those is repaired in the file afterwards, so
  tables arrive as tables and code arrives monospaced on Windows too.
* **Diagrams are drawn into every export**, HTML, Word and EPUB alike,
  rather than shipping the source and a library and hoping the reader runs
  JavaScript.

### An editor that draws the Markdown

The editor stops showing you the markup and starts drawing what it means.
None of it touches the file: what you save is the string you typed, to the
character.

* **The markers disappear** until the caret reaches them — emphasis, bold,
  inline code, links, the hashes on a heading and the `>` on a quotation.
  They collapse the moment a construct is finished, and come back the
  moment you work on it.
* **Blocks are laid out**: lists get a hanging indent, quotations get a
  rule down the margin, headings get room above them, and three dashes are
  drawn as a line across the page.
* **Tables are edited by command**, not by hand: right-click one for rows
  and columns, a column's alignment, or a repair of its dashes row. The
  editor shows the source; the columns are drawn in the preview, which has
  the room for them. Click a cell there and the caret goes to that cell.
* **Closer to CommonMark and GitHub**: a hash with no space after it is a
  hashtag and not a heading, `1)` numbers a list as `1.` does, a list that
  starts at five is numbered from five, a backslash at the end of a line
  breaks it, and a task marker is accepted in either case.
* **One window, one tab per open file**, using the system's own tabs — so
  ⇧⌘\ shows the overview, tabs drag between windows, and a link to a file
  that is already open goes to the tab it is open in rather than opening it
  twice.
* **Writing help that runs on your Mac**: improve, correct, make formal,
  make plain, shorter, longer — over the selection, or the paragraph the
  caret is in. The answer streams in and one undo takes it all back.
  Nothing is sent anywhere: a GGUF model runs locally through llama.cpp,
  and the Models panel downloads and installs one without any other tool —
  from a short curated list, or from any address you paste. Turn the whole
  thing off in the preferences if you would rather not have it.
* **Document templates written by hand**, not generated: a commissioning
  report, a software test plan, release notes, minutes. Instant, the same
  every time, and there with no model installed. Put your own in the
  Templates folder and they appear in the menu.
* **Link to a file that does not exist yet.** Select the words the link
  should say, right-click, and there is an empty Markdown file beside the
  document, linked, open in its own tab. Named after the selection, so a
  set of notes grows by writing rather than by filing.
* **⌘K asks where the link goes**: a web address you type or paste, or a
  file you find by browsing. A file inside the document's folder is written
  as a relative path, so the two keep working when you move them together.
* **⌘B and ⌘I act on the word under the caret** when nothing is selected,
  and take the markup off again if it is already there.
* **Pasting formatted text produces Markdown** — headings, nested lists,
  links, images, fenced code with its language, quotations, tables. ⌘⇧V
  pastes exactly what was copied.
* Deleting at the start of a heading's text demotes it to a paragraph; at
  the start of a quoted line it unquotes the line.

Every one of these can be switched off in **Preferences › Rendering ›
Writing**.

* **Tables are edited by command**: rows and columns inserted and deleted,
  moved up, down, left and right, a column's alignment set from a submenu,
  and a mangled `|---|` row repaired — an em dash in it stops the block
  being a table at all and looks identical to one that works. **Copy Table
  As** hands it to a spreadsheet, a form or a page: tab-separated,
  comma-separated or HTML.

### Drawing

* **Draw a Diagram from a Description…** (⌃⌥⌘G, or the editor's context
  menu): describe a flow, a sequence or a structure in your own language and
  the model on your Mac writes the Mermaid for it, with the labels in that
  language. The source comes back editable, drawn beside it as you type by
  the same Mermaid the preview uses, and it can only go into the document
  once it has actually drawn — a source Mermaid refuses shows its complaint
  instead. It also says so when the model writes `if` and `endif` into the
  labels, which is what a small model does instead of drawing a branch.

### Comparing

* **Compare with…** (⌃⌥⌘D) shows the document beside another file, with what
  differs marked. The left side is what is in the editor, unsaved changes
  included. A changed line is one row carrying both versions, with the words
  that differ marked inside it; the columns keep their own line numbers, mark
  the margin (`~`, `+`, `−`) for people who do not separate red from green,
  and scroll together by row. It can compare **by paragraph** instead of by
  line, and ignore spaces or case: a document that has only been re-wrapped
  reads as 181 changed rows by line and 9 by paragraph. Differences only, next, previous, swap sides, and read
  the files again for when somebody else has just saved.

### Collecting

* **Save a web page as Markdown**, beside the document: the address and the
  date go at the top as front matter, so a clipping is never a quotation
  without a source. What surrounds the page — scripts, navigation, headers,
  footers, asides — is left behind, and if the page says which part is the
  article, that part is taken. From an unsaved document it opens as a
  document of its own, to be saved wherever you like — a page worth keeping
  is worth keeping before the notes it belongs to have a name. Addresses are
  made absolute against the page
  they came from, so its pictures and links still point somewhere once the
  text is a file in your folder; the clipping is linked where the caret was,
  and opened in a tab. The conversion is the one used for pasting, so what
  arrives is what copying the page would have given.
* **How long it takes to read**, in the counter beside the words and the
  characters. Two hundred words a minute, which is a figure and not a
  measurement: what it is for is telling a page from a chapter.
### Reading and writing

* **Read only**, ⌥⌘L: a lock in the title bar, the text still selectable,
  and the commands that edit refused — the text view turns down what is
  typed into it but not what is done to it, so ⌘B would otherwise still put
  asterisks in a document that says it cannot change. Per window, not
  remembered.
* **Focus mode** and **typewriter scrolling**, ⌃⌥⌘F and ⌃⌥⌘T: everything but
  the paragraph you are writing dimmed, and that paragraph kept two fifths
  down the window instead of walking to the bottom. The dimming is drawing
  and not text: it goes through the layout manager's temporary attributes,
  so it cannot reach the file.
* **Move completed tasks to the end** of the list the caret is in, on
  command rather than by itself — a list is often in the order it is in on
  purpose. An item takes its continuation lines and its nested tasks with
  it.

### Agreement between the two panes

* A heading needs the space after its hashes — `## Titolo`, not `##Titolo` —
  because CommonMark, GitHub and the renderer here all require it, and
  because `#riunione` at the start of a line is a hashtag and not a
  first-level heading. The editor's parser used to disagree with the
  renderer about exactly that, colouring as a heading a line the preview
  drew as a paragraph; it no longer does.
* The prose panel reports those lines — "titolo senza spazio" — with a
  **Correggi** button, the one finding there that has a single obvious
  answer. The rest are matters of judgement and get no button.

* **One selection, in two panes.** Select words in the preview and, when
  the gesture ends, the same words are selected in the source with the
  focus there: delete removes them, typing replaces them. It works the
  other way round too — select a sentence in the editor and the page marks
  it, so you can see which paragraph you are about to change.
* Which words, exactly, is the whole problem: the rendered text is not the
  source. The search happens inside the block the selection came from, the
  page says how much of its own text came before it — so the second "test"
  of a paragraph is the second one — and what the renderer changed on the
  way out is undone on the way back: `“così”` finds `"così"`, `l’editor`
  finds `l'editor`, `10–12` finds `10--12`. A selection that cannot be
  placed with certainty leaves the editor alone rather than selecting
  nearly the right thing, and says so by leaving the words marked in the
  page with a dotted line.
* Any gesture counts: the mouse, ⇧ and the arrows, ⌘A, a drag that ends
  outside the page. Only a mouse released *in* the page moves the focus —
  somebody still holding shift is not finished — and delete pressed on a
  preview selection takes those words out of the source.

### When the file changes underneath

* **A file rewritten while it is open is noticed.** With nothing of yours in
  hand the document reloads, keeping the caret where it was; with unsaved
  changes it asks once — *Ricarica dal file* or *Tieni quello che ho* —
  because both sides then have something the other has not. `git` checking
  out a branch and an agent saving over a document are the same event as far
  as an editor is concerned, and until now it was silent about both.
* **A version is kept before the machine rewrites your words.** The writing
  commands, a prose fix and moving done tasks to the end save the document
  first, so File ▸ Revert To ▸ Browse All Versions has a point just before
  the change — ⌘Z does not survive closing the window. Nothing new holds
  those versions: they are the system's, in its own store, read from its
  own menu.
* **A file that has gone says so**, with the path, and offers *Salva con
  nome…*. Reverting says it too, instead of letting macOS report it as a
  failure to save: nothing was being saved, and "could not be saved in the
  folder docs" is a true sentence that explains nothing.

### When something does not work

* **Help › Record What I Do.** Off unless you switch it on, and then every
  command and its answer goes into `~/Library/Logs/MacDown Next/actions.log`
  — what a backlink search read, what a command answered. Nothing leaves
  the Mac; the menu shows the file in the Finder and empties it. It exists
  because the alternative was guessing at what somebody else's screen was
  doing.

### Keeping it up to date

* **MacDown Next ▸ Check for Updates…**, and once a day on its own unless
  you turn that off in **Preferences › Updates**. Four questions in order:
  is there a newer release, shall it be downloaded, here it is — shall the
  disk image be opened, and then the application quits and gets out of the
  way. Dragging the new copy into Applications stays yours to do: nothing
  replaces the running application behind your back.
* The download goes to **Downloads**, with a progress bar and a **Stop**
  that really stops it, and it will not overwrite a file already there.
  The check is a request to GitHub's list of releases and nothing else
  leaves the machine; the disk image is only fetched from GitHub, checked
  when the list is read and again before the download starts.

### Working with agents

* **Send to Claude** and **Send to ChatGPT**: the document, or the selection,
  on the clipboard and a new chat with the prompt field filled in — filled
  in, not sent.
* **Instruction Files…** (⌃⌥⌘I) reads `CLAUDE.md` and `AGENTS.md` as the
  small system they are: which files apply and in what order, every `@path`
  import resolved into a tree, and what is wrong with the set — an import
  that leads nowhere, one that closes a circle, one past the fourth hop
  where the loader stops, a file too long to be read well, an `AGENTS.md`
  that nothing imports.
* **An MCP server over one folder.** `macdownext-mcp`, beside `macdownext`
  in `Contents/SharedSupport/bin`, hands a declared folder to Claude Code,
  Claude Desktop or any other MCP client over a pipe — **search**, **read**,
  **list**, **outline**, **backlinks** (who cites a document),
  **frontmatter** and **find_by_field** (which documents declare one).
  Citations and front matter are worked out by the code the editor itself
  runs, so a document cannot be cited in one and uncited in the other.
  Started with `--append` or `--write` it can also add to the end of a
  document, make one that is not there, and replace text that is — saying
  how many times and on which lines. Nothing deletes, nothing renames,
  nothing writes over a file that exists, and every call (refusals included)
  goes into `~/Library/Logs/MacDown Next/mcp.log`, which leaves nowhere.
  **Settings ▸ Agents** builds the line to paste into the client, shows what
  has been asked of the folder, and holds the switch that turns the whole
  thing off — off, the server refuses to start, whatever a client has in its
  configuration. No tool writes, renames or
  deletes; a path outside the folder is refused; a second `--root` is an
  error rather than a second permission; text only, 2 MB at most, a
  `.textbundle` counted as one document. The application does not have to be
  running, because what it reads is the folder.

### In the Finder

* **Markdown files preview as they read.** Press space on a `.md` file and
  Finder shows the document — headings, tables, code, to-do boxes — with
  the same style sheet the application opens with, instead of the source.
  Pictures kept beside the document travel with the preview; the page
  itself cannot reach the network, so a document that asks for a remote
  image does not get one.
* **Diagrams and formulas are drawn there too**: mermaid, all six Graphviz
  engines, and TeX through MathJax. The page has no scripts in it, so the
  extension draws them in a web view of its own and puts finished SVG in
  the page — only loading the libraries a document actually needs, with two
  and a half seconds for all the drawings of one document and whatever is
  not drawn by then left as source. What counts as a formula follows the
  application's own switch, read from its preferences: `$$…$$` always, a
  single `$…$` only when *TeX-like math syntax* is on, because otherwise
  "costs $5 and $7" reads as algebra.
* **WikiLinks are links there as well.** `[[Verbale]]` resolves against the
  document's folder — the name as written, then `.md`, `.markdown`, `.txt`
  — and a target that does not exist yet is marked, as it is in the editor.
  A document should read the same closed as open.
* **Preferences › Quick Look** says where that preview stands and does
  something about it: whether macOS has it, which copy of the application
  is providing it, and which version — with **Install**, **Update** when
  the registered build is older than the one in hand, and **Remove**.
  Worth a panel because the registration goes wrong quietly: a copy left
  in the Downloads folder can hold it, and a preview that does not appear
  says nothing at all.

### Plug-ins

* **A draw.io importer**, as a real plug-in (`Drawio.plugin`): pick a
  `.drawio` file and every page in it becomes a PNG beside the document,
  linked where the caret is. Drawn by draw.io's own viewer **and its 97
  shape libraries** — AWS, Cisco, Azure, GCP, BPMN and the rest — all of
  which travel inside the plug-in, 23 MB of them stored as 3. Every address
  in the page points back into the bundle, so **nothing is sent and nothing
  is fetched**: it draws with no connection at all. An export server of your
  own can be used instead. Compressed pages, editable PNGs and editable
  SVGs are all read. See
  [plugins/Drawio/README.md](plugins/Drawio/README.md).

### Writing

* **A prose checker**: qualifiers, weasel words, hedging, wordiness, passive
  tells and repeated words, in **English and Italian**. The word lists are a
  resource file, editable without rebuilding. The tally sits under the
  window title, and **⌃⌥⌘P lists what it counted**: every flagged word with
  its line, and clicking one goes to it.
* **A maths editor** for TeX, with a live preview, backed by a bundled
  MathJax — so formulas render with no network.
* **WikiLinks**: `[[Another note]]` links to a neighbouring document, and
  says so when the file is not there.
* **Which documents point at this one**, ⌃⌥⌘B: the folder is read and every
  citation listed with its line and the sentence around it, `[[wiki]]` and
  `[relative](links.md)` alike; clicking one opens that document at that
  line. A link says where it goes and nothing said what points here, so the
  question used to be a `grep`.
* **A sidebar** with the document outline, for moving around a long file.
* **The code button asks which kind**: backticks inside the line, or a
  fenced block marked with a language chosen from a list — and the list
  holds only the 113 languages this build can actually highlight.
* **Right-click inside a code block to lay it out** the way its language
  wants: brackets for the C family and JSON, tags for HTML, and for Python,
  YAML or a Makefile — where the indentation *is* the syntax — the step
  only, never the structure. A comment that runs over lines moves whole, so
  its column of asterisks holds; multi-line strings and code that is
  aligned rather than indented are left alone.

### Appearance

* Built against the macOS 26 SDK, with the window chrome to match: content
  runs the full height under a unified toolbar, which picks up the glass
  material and the scroll edge effect.
* **The preview has a dark mode**, and follows the system.
* **Typing no longer makes the preview flash.** It used to reload the whole
  page on every keystroke.
* **The two panes point at the same place.** Put the caret in a paragraph
  and a rule marks it in the preview; select in the preview and a rule
  marks it in the editor's margin.
* A **new application icon**, and no Touch Bar: the strip is gone from the
  hardware, and every command it carried is on the menu and the toolbar.

## Installing

Builds are on the [releases page](https://github.com/nicolorisitano82/macdown-next/releases).
Requires macOS 26.

They are **not signed or notarised** — no Developer ID certificate stands
behind them — so macOS will refuse one on a double-click. After dragging the
app to Applications:

    xattr -d com.apple.quarantine "/Applications/MacDown Next.app"

Whether to run an unsigned binary from the internet is your call; building
from source is the alternative, and the next section says how.

## License

MacDown Next is released under the terms of MIT License. You may find the content of the license [here](http://opensource.org/licenses/MIT), or inside the `LICENSE` directory.

You may find full text of licenses about third-party components in the `LICENSE` directory, or the **About MacDown Next** panel in the application.

The following editor themes and CSS files are extracted from [Mou](http://mouapp.com), courtesy of Chen Luo:

* Mou Fresh Air
* Mou Fresh Air+
* Mou Night
* Mou Night+
* Mou Paper
* Mou Paper+
* Tomorrow
* Tomorrow Blue
* Tomorrow+
* Writer
* Writer+
* Clearness
* Clearness Dark
* GitHub
* GitHub2

## Notes on the design

Journals of the work, in Italian: [the editor's text rendering](docs/wysiwyg-testo.md),
[the local writing help](docs/ai-locale.md) and
[the two previews](docs/anteprime.md) — the card under the pointer and the
one Finder draws — [the selection the two panes share](docs/selezione.md),
[where the work goes](docs/salvataggi.md)
and [the MCP server over a folder](docs/progetto-mcp.md), which reads it
for an assistant and can do nothing else,
[the plan for syncing a folder](docs/progetto-sync.md)
and [the updater](docs/aggiornamenti.md). There is also a
study, not a plan: [what a Claude and GPT integration could
be](docs/studio-claude-gpt.md), and which parts of it are worth having, and
[what the comparison panel still needs](docs/studio-confronto.md), which
starts from a measurement: one word changed in a re-wrapped document shows
up as a hundred and eighty changed lines. They are written for whoever picks a piece of this up
next — what was measured, and the several times the measuring contradicted
me.

## Development

### Requirements

* Xcode 26 or later, for the macOS 26 SDK. The deployment target is macOS
  26.0, so an older SDK will not build this.
* Git
* CocoaPods

> The Command Line Tools alone are not enough. `xcodebuild` refuses to run
> against them:
>
>     xcode-select: error: tool 'xcodebuild' requires Xcode, but active
>     developer directory is a command line tools instance
>
> If Xcode is installed but `xcode-select` points elsewhere, either repoint
> it or set `DEVELOPER_DIR` for the build.

> CocoaPods is easiest from Homebrew — `brew install cocoapods` — which
> brings its own Ruby. The Ruby that ships with macOS is too old for current
> CocoaPods, so `gem install cocoapods` against it tends to end without a
> usable `pod`. The `Gemfile` route works too if you already run a modern
> Ruby.

### Environment Setup

After cloning the repository, run the following inside the repository root:

    git submodule update --init
    pod install
    make -C Dependency/peg-markdown-highlight
    Tools/build_llama.sh

and open `MacDown.xcworkspace` — the workspace, not the project; the project
alone has no pods. The first command fetches the dependency submodules, the
second installs the CocoaPods dependencies, and the last two build the
dependencies that come with their own build system — the editor's highlighter
and llama.cpp, which the writing commands generate through. `Tools/build_llama.sh`
needs `cmake` and takes about fifteen seconds.

If a build fails later on after pulling, the same two commands usually
account for it:

    git submodule update
    pod install

### Checking a build

The XCTest suite says the code does what it says. Some of this application
is not code the suite can reach: the Quick Look extension runs out of
process, in a sandbox, and only if macOS agrees to register it. One command
covers both:

    Tools/verify_features.sh

It builds, runs the suite, then reads the built product — is the extension
inside the app, is it signed and sandboxed, does it declare a data-based
preview — builds the very page Finder would be handed and checks what is in
it, and finally registers the app and asks Quick Look for a real preview,
confirming from the system log that our extension served it. The exit
status is the number of checks that failed.

`--no-build`, `--no-tests` and `--no-finder` cut it short; the last of
these leaves Launch Services alone. `--configuration Release` checks what
would be released. Two warnings the script has learned the hard way and
that are worth knowing by hand as well: `codesign --deep` strips the
entitlements of the nested extension, so an app signed that way has a Quick
Look extension macOS will silently ignore, and `lsregister -f` alone does
not replace a registration that is already there — `lsregister -u` first.

## Credits

MacDown Next leans on other open source projects:
[Hoedown](https://github.com/hoedown/hoedown) turns Markdown into HTML,
[Prism](https://prismjs.com) highlights code blocks,
[PEG Markdown Highlight](https://github.com/ali-rantakari/peg-markdown-highlight)
highlights the editor, [mermaid](https://mermaid.js.org) and
[Graphviz](https://graphviz.org), through
[Viz.js](https://github.com/mdaines/viz.js), draw the diagrams, and
[MathJax](https://www.mathjax.org) sets the maths.

They have the credit for the parts they do. Problems you run into here are
still best [reported here](https://github.com/nicolorisitano82/macdown-next/issues):
telling apart a fault in this fork, in the MacDown it grew out of, and in
something underneath is rarely possible from the outside, and it is not the
reporter's job.
