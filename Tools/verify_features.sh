#!/bin/bash
#
# Tools/verify_features.sh — the control suite.
#
# The unit tests say the code does what it says. This says the built
# application does: it looks at the product, at the page Finder would be
# handed, and at whether macOS actually hands a Markdown file to our
# extension. Those three live outside XCTest — in the bundle, in another
# process, and in Launch Services — which is exactly where the mistakes
# that survive a green suite hide.
#
#   Tools/verify_features.sh                 build, test, check everything
#   Tools/verify_features.sh --no-build      use the products already built
#   Tools/verify_features.sh --no-tests      skip the XCTest suite
#   Tools/verify_features.sh --no-finder     do not touch Launch Services
#   Tools/verify_features.sh --configuration Release
#
# Exit status is the number of checks that failed, so it is 0 when all is
# well and usable from a script.

set -u
cd "$(dirname "$0")/.."

CONFIGURATION=Debug
DO_BUILD=1
DO_TESTS=1
DO_FINDER=1

while [ $# -gt 0 ]; do
    case "$1" in
        --no-build)  DO_BUILD=0 ;;
        --no-tests)  DO_TESTS=0 ;;
        --no-finder) DO_FINDER=0 ;;
        --configuration) shift; CONFIGURATION="$1" ;;
        -h|--help)   sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "opzione sconosciuta: $1" >&2; exit 2 ;;
    esac
    shift
done

WORK=$(mktemp -d "${TMPDIR:-/tmp}/macdown-verifica.XXXXXX")
# The sandbox the Finder preview runs in can read the home folder and not
# much else, so the document a real preview is asked for has to live there.
HOME_WORK="$HOME/.macdown-verifica"
# Extensions ignored to make room for the copy under test are put back,
# however this run ends: leaving somebody's installed preview turned off
# would be a rude way to fail.
restore_extensions() {
    [ -s "$WORK/ignored" ] || return 0
    while read -r other; do
        [ -n "$other" ] && pluginkit -e use -i "$other" >/dev/null 2>&1
    done < "$WORK/ignored"
    : > "$WORK/ignored"
}
trap 'restore_extensions; rm -rf "$WORK" "$HOME_WORK"' EXIT

PASSED=0
FAILED=0
SKIPPED=0

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# ok "what was expected" <test command...>
ok() {
    local what="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf '  \033[32m✓\033[0m %s\n' "$what"
        PASSED=$((PASSED + 1))
    else
        printf '  \033[31m✗\033[0m %s\n' "$what"
        FAILED=$((FAILED + 1))
    fi
}

# Same, for the common case of "this text is in that file".
contains() { grep -qF -- "$2" "$1"; }
absent()   { ! grep -qF -- "$2" "$1"; }

skip() {
    printf '  \033[33m–\033[0m %s\n' "$1"
    SKIPPED=$((SKIPPED + 1))
}

xcode() {
    DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer} \
        xcodebuild -workspace MacDown.xcworkspace -scheme MacDown \
                   -configuration "$CONFIGURATION" "$@"
}


# --------------------------------------------------------------- the build

if [ "$DO_BUILD" = 1 ]; then
    say "Costruzione ($CONFIGURATION)"
    if xcode build > "$WORK/build.log" 2>&1; then
        printf '  \033[32m✓\033[0m build riuscita\n'
        PASSED=$((PASSED + 1))
        # The copy in dist/ is made here rather than by the build phase:
        # that one runs in the middle of the target, before the Info.plist
        # is written, so on a clean build it has nothing finished to copy.
        bash Tools/copy_to_dist.sh "$CONFIGURATION" \
            >> "$WORK/build.log" 2>&1 || true
    else
        printf '  \033[31m✗\033[0m build fallita — %s\n' "$WORK/build.log"
        grep -E " error: " "$WORK/build.log" | head -5
        exit 1
    fi
fi

PRODUCTS=$(xcode -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/^ *BUILT_PRODUCTS_DIR = /{print $2; exit}')
# One application comes out of this workspace; taking it by name would mean
# knowing how the target renames it per configuration.
APP=$(ls -d "$PRODUCTS"/*.app 2>/dev/null | head -1)
if [ ! -d "$APP" ]; then
    echo "l'applicazione costruita non si trova: $APP" >&2
    exit 1
fi
APPEX="$APP/Contents/PlugIns/MacDownQuickLook.appex"
echo "  · $APP"


# --------------------------------------------------------------- the suite

if [ "$DO_TESTS" = 1 ]; then
    say "Prove unitarie"
    # Signing is left alone on purpose: `CODE_SIGNING_ALLOWED=NO` would
    # leave the extension in the products unsigned, and the checks below
    # would then be looking at something that is not what gets shipped.
    xcode test > "$WORK/test.log" 2>&1
    LINE=$(grep -Eo "Executed [0-9]+ tests, with [0-9]+ failures" \
           "$WORK/test.log" | tail -1)
    if [ -n "$LINE" ]; then
        echo "  · $LINE"
    fi
    ok "suite verde" grep -q "TEST SUCCEEDED" "$WORK/test.log"
    if ! grep -q "TEST SUCCEEDED" "$WORK/test.log"; then
        grep -E "Tests\.m:[0-9]+: error" "$WORK/test.log" | sort -u | head -5
    fi
    # The two features of this branch have their own classes; a suite that
    # is green because they were not run is not evidence.
    for CLASS in MPLinkPreviewTests MDPreviewPageTests MPHoverWatchTests \
                 MPQuickLookExtensionTests MPUpdateTests; do
        ok "$CLASS ha girato" grep -q "$CLASS" "$WORK/test.log"
    done
fi


# ------------------------------------------------- the extension as shipped

say "L'estensione dentro l'applicazione"
ok "l'.appex viaggia nell'app" test -d "$APPEX"

if [ -d "$APPEX" ]; then
    PLIST="$APPEX/Contents/Info.plist"
    read_plist() { /usr/libexec/PlistBuddy -c "Print $1" "$PLIST" 2>/dev/null; }

    ok "punto di estensione: anteprima di Quick Look" \
        test "$(read_plist :NSExtension:NSExtensionPointIdentifier)" \
             = "com.apple.quicklook.preview"
    ok "classe principale MDQuickLookProvider" \
        test "$(read_plist :NSExtension:NSExtensionPrincipalClass)" \
             = "MDQuickLookProvider"
    # Without this the system treats it as having a view to show, and dies
    # in QLPreviewExtensionViewController.
    ok "dichiarata anteprima a dati (QLIsDataBasedPreview)" \
        test "$(read_plist :NSExtension:NSExtensionAttributes:QLIsDataBasedPreview)" \
             = "true"
    ok "si offre per net.daringfireball.markdown" \
        grep -q "net.daringfireball.markdown" \
        <(read_plist :NSExtension:NSExtensionAttributes:QLSupportedContentTypes)
    # I due contenitori che l'applicazione dichiara di aprire. Senza il
    # tipo, il Finder non le manda il file e nessuno se ne accorge.
    ok "l'app si offre per Textbundle e Textpack" \
        grep -q "org.textbundle" \
        <(/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes" \
          "$APP/Contents/Info.plist" 2>/dev/null)
    ok "e dichiara i due tipi, che nessun altro potrebbe dichiarare" \
        grep -q "org.textbundle.pack" \
        <(/usr/libexec/PlistBuddy -c "Print :UTImportedTypeDeclarations" \
          "$APP/Contents/Info.plist" 2>/dev/null)
    ok "lo stile dell'app è dentro l'estensione" \
        test -f "$APPEX/Contents/Resources/GitHub2.css"
    ok "e lo stile dei WikiLink con esso" \
        test -f "$APPEX/Contents/Resources/wikilink.css"
    # Le tre librerie che disegnano. Senza, un diagramma resta il suo
    # sorgente e nessuno lo dice.
    ok "porta mermaid, Graphviz e MathJax" \
        test -f "$APPEX/Contents/Resources/mermaid.min.js" \
             -a -f "$APPEX/Contents/Resources/viz.js" \
             -a -f "$APPEX/Contents/Resources/tex-svg.js"


    # Quick Look loads sandboxed extensions only, and `codesign --deep` on
    # the app quietly strips the nested entitlements. Both are invisible
    # until a preview does not appear.
    codesign -d --entitlements - --xml "$APPEX" > "$WORK/rights.plist" 2>/dev/null
    ok "firmata" codesign --verify --strict "$APPEX"
    ok "può usare WebKit, che pretende il permesso di rete" \
        grep -q "com.apple.security.network.client" \
        <(codesign -d --entitlements - --xml "$APPEX" 2>/dev/null | plutil -p -)
    ok "in sandbox (o Quick Look non la carica)" \
        contains "$WORK/rights.plist" "com.apple.security.app-sandbox"
    ok "può leggere le figure accanto al documento" \
        contains "$WORK/rights.plist" \
        "com.apple.security.temporary-exception.files.home-relative-path.read-only"
fi


# ------------------------------------------------- and the copy that ships

# The version and the seal only come together on the copy in dist/: the
# build system rewrites the extension's Info.plist at the end of its own
# target, so the stamp goes on afterwards, and the signature with it. The
# panel in Preferences compares the registered version with this one, so a
# copy left at its placeholder version would offer an update for ever.
DIST_APP=$(ls -d "dist/$CONFIGURATION"/*.app 2>/dev/null | head -1)
DIST_APPEX="$DIST_APP/Contents/PlugIns/MacDownQuickLook.appex"

say "La copia che si distribuisce"
if [ -z "$DIST_APP" ] || [ ! -d "$DIST_APPEX" ]; then
    skip "niente in dist/$CONFIGURATION"
else
    DIST_VERSION=$(/usr/libexec/PlistBuddy -c \
        "Print :CFBundleShortVersionString" "$DIST_APPEX/Contents/Info.plist" \
        2>/dev/null)
    DIST_APP_VERSION=$(/usr/libexec/PlistBuddy -c \
        "Print :CFBundleShortVersionString" "$DIST_APP/Contents/Info.plist" \
        2>/dev/null)
    echo "  · $DIST_APP"
    ok "l'estensione porta la versione dell'app ($DIST_APP_VERSION)" \
        test -n "$DIST_VERSION" -a "$DIST_VERSION" = "$DIST_APP_VERSION"
    ok "e la firma regge lo stampo" \
        codesign --verify --strict "$DIST_APPEX"
    codesign -d --entitlements - --xml "$DIST_APPEX" \
        > "$WORK/dist-rights.plist" 2>/dev/null
    ok "con la sandbox ancora dichiarata" \
        contains "$WORK/dist-rights.plist" "com.apple.security.app-sandbox"
fi


# ------------------------------------------- the page Finder would be given

say "La pagina che il Finder riceverebbe"

DOC="$HOME_WORK/verbale di prova.md"
mkdir -p "$HOME_WORK"
# A small red square, so that a picture beside the document is a real file.
python3 - "$HOME_WORK/rete.png" <<'PY'
import base64, sys, pathlib
pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(
 b'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAP0lEQVR4nO3PsQ3AMAwDwf//'
 b'6bIFF3ARJ0AKFncdSRAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPBvHnGgAAHkPTHT'
 b'AAAAAElFTkSuQmCC'))
PY
cat > "$DOC" <<'EOF'
---
title: da scartare
source: https://esempio.it
---

# Relazione di prova

[TOC]

Un paragrafo con **grassetto** e un [collegamento](altro.md).

## Cose da fare

- [ ] comprare il pane
- [x] pagare la bolletta
- voce normale

| Voce | Quantità |
|------|----------|
| pane | 2        |

```python
def saluta(nome):
    return f"ciao {nome}"
```

![rete](rete.png)

![fuori](https://esempio.it/tracciante.png)

Vedi [[vicino]] e anche [[manca-del-tutto|questa che non c'è]].
EOF

# A WikiLink resolves against the document's own folder, so the target has
# to be a real file for the check to mean anything.
printf 'accanto\n' > "$HOME_WORK/vicino.md"

if clang -fobjc-arc -framework Foundation -IQuickLook \
         -IDependency/hoedown/src -o "$WORK/quicklook_page" \
         Tools/quicklook_page.m QuickLook/MDPreviewPage.m \
         Dependency/hoedown/src/*.c > "$WORK/harness.log" 2>&1
then
    "$WORK/quicklook_page" "$DOC" MacDown/Resources/Styles/GitHub2.css \
        > "$WORK/page.html"
    "$WORK/quicklook_page" "$DOC" --pictures > "$WORK/pictures.txt"

    ok "il titolo è quello del documento" \
        contains "$WORK/page.html" "<title>Relazione di prova</title>"
    # `[TOC]` is a second pass with another renderer, and the preview used
    # to show the four letters where the application shows the headings.
    ok "l'indice chiesto col [TOC] è un elenco di titoli" \
        sh -c 'grep -q "toc_1" "$0" && ! grep -q "\\[TOC\\]" "$0"' \
        "$WORK/page.html"
    ok "il front-matter resta fuori" \
        absent "$WORK/page.html" "da scartare"
    ok "lo stile dell'app è nella pagina" \
        contains "$WORK/page.html" "font-family: Helvetica"
    ok "i to-do sono caselle" \
        contains "$WORK/page.html" '<li class="task"><input type="checkbox" disabled>'
    ok "un to-do fatto è una casella segnata" \
        contains "$WORK/page.html" 'disabled checked'
    ok "le tabelle sono tabelle" contains "$WORK/page.html" "<table"
    ok "il codice è evidenziabile (class=language-)" \
        contains "$WORK/page.html" 'class="language-python"'
    ok "la figura accanto viaggia come allegato" \
        contains "$WORK/page.html" 'src="cid:pict0"'
    ok "e l'allegato è quel file" \
        grep -q "rete.png" "$WORK/pictures.txt"
    ok "la figura remota è lasciata dov'è" \
        contains "$WORK/page.html" "https://esempio.it/tracciante.png"
    ok "e non può essere scaricata" \
        contains "$WORK/page.html" "default-src 'none'"
    ok "niente script nella pagina" absent "$WORK/page.html" "<script"
    ok "un WikiLink al file accanto è un collegamento" \
        contains "$WORK/page.html" '<a href="vicino" class="wikilink">'
    ok "e uno che non porta a niente lo dice" \
        contains "$WORK/page.html" 'class="wikilink wikilink-missing"'

else
    skip "banco di prova non compilato — $WORK/harness.log"
fi


# --------------------------------------------------- and what GitHub says

# The panel that offers an update reads this feed. The tests read a copy of
# it; this reads the real one, because a feed that changes shape would leave
# the application quietly never offering anything.
say "L'elenco dei rilasci"

FEED="$WORK/feed.json"
STATUS=$(curl -sS -o "$FEED" -w '%{http_code}' \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: MacDownNext/verifica" \
    "https://api.github.com/repos/nicolorisitano82/macdown-next/releases/latest" \
    2>/dev/null || echo 000)

if [ "$STATUS" != "200" ]; then
    skip "GitHub ha risposto $STATUS (nessuna rete?)"
elif ! clang -fobjc-arc -framework Cocoa -IMacDown/Code/Utility \
        -o "$WORK/update_feed" Tools/update_feed.m \
        MacDown/Code/Utility/MPUpdate.m > "$WORK/feedharness.log" 2>&1
then
    skip "banco di prova del feed non compilato — $WORK/feedharness.log"
else
    "$WORK/update_feed" "$FEED" "0.0.1" > "$WORK/feed.txt" 2>&1 || true
    READ_VERSION=$(awk -F'\t' 'NR==1{print $1}' "$WORK/feed.txt")
    READ_URL=$(awk -F'\t' 'NR==1{print $2}' "$WORK/feed.txt")
    READ_SIZE=$(awk -F'\t' 'NR==1{print $3}' "$WORK/feed.txt")
    TAG=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null | sed 's/^v//')

    ok "il rilascio si legge ($READ_VERSION)" test -n "$READ_VERSION"
    ok "ed è l'ultimo tag di qui ($TAG)" test "$READ_VERSION" = "$TAG"
    ok "con un'immagine disco su GitHub" \
        grep -qE '^https://(github\.com|objects\.githubusercontent\.com)/' \
        <(echo "$READ_URL")
    ok "e una dimensione da mostrare" test "${READ_SIZE:-0}" -gt 0
    # The whole point of the comparison: an old version is offered the new
    # one, and the version in hand is not offered itself.
    ok "a chi ha una versione vecchia viene offerto" \
        grep -qx "offerto" <(tail -1 "$WORK/feed.txt")
    "$WORK/update_feed" "$FEED" "$READ_VERSION" > "$WORK/feed-same.txt" 2>&1 || true
    ok "a chi ha già questa, no" \
        grep -qx "niente da offrire" <(tail -1 "$WORK/feed-same.txt")
fi


# ----------------------------------------------- and whether macOS uses it

say "Quello che fa il sistema"

if [ "$DO_FINDER" = 0 ]; then
    skip "registrazione e anteprima vera (--no-finder)"
elif [ ! -d "$APPEX" ]; then
    skip "registrazione e anteprima vera (manca l'.appex)"
else
    LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
    IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
                 "$APPEX/Contents/Info.plist" 2>/dev/null)
    # `-f` alone does not replace a record that is already there, and the
    # extension then stays invisible however often it is repeated.
    "$LSREGISTER" -u "$APP" >/dev/null 2>&1
    sleep 1
    "$LSREGISTER" -f -R -trusted "$APP" >/dev/null 2>&1
    sleep 5

    # Two copies of this extension can be present at once — the one in
    # /Applications and the one just built — and macOS asks one of them.
    # Until this was measured the live checks were reading the *installed*
    # extension, and passing on code nobody had just changed.
    pluginkit -m -p com.apple.quicklook.preview 2>/dev/null \
        | sed -n 's/.*[[:space:]]\(com\.[^(]*macdown[^(]*\)(.*/\1/p' \
        | grep -v "^$IDENTIFIER$" > "$WORK/ignored" || true
    while read -r other; do
        [ -n "$other" ] && pluginkit -e ignore -i "$other" >/dev/null 2>&1
    done < "$WORK/ignored"
    pluginkit -e use -i "$IDENTIFIER" >/dev/null 2>&1
    sleep 2

    ok "il sistema la elenca fra le anteprime" \
        grep -q "$IDENTIFIER" <(pluginkit -m -p com.apple.quicklook.preview \
                                2>/dev/null)

    # Quick Look keeps previews, so a fresh name is the only way to be sure
    # the extension is asked again rather than a cached page shown.
    FRESH="$HOME_WORK/$(date +%s)-$RANDOM.md"
    cp "$DOC" "$FRESH"
    SINCE=$(date "+%Y-%m-%d %H:%M:%S")
    (qlmanage -p "$FRESH" >/dev/null 2>&1 &)
    sleep 8
    pkill -x qlmanage >/dev/null 2>&1
    /usr/bin/log show --start "$SINCE" \
        --predicate 'process == "MacDownQuickLook"' --style compact \
        > "$WORK/extension.log" 2>/dev/null

    ok "l'estensione viene avviata e serve la richiesta" \
        contains "$WORK/extension.log" "beginning extension request"
    ok "e non muore per un'asserzione del sistema" \
        absent "$WORK/extension.log" "Assertion failure"

    # The diagrams are drawn in a web view of the extension's own, and that
    # is the part that can only be tried for real: measured, WebKit inside
    # this sandbox draws in under half a second, and without the entitlement
    # it never finishes loading at all.
    DIAGRAM="$HOME_WORK/$(date +%s)-$RANDOM-diagramma.md"
    cat > "$DIAGRAM" <<'FINE'
# Diagrammi e formule

```mermaid
graph TD
  A[Inizio] --> B[Fine]
```

```dot
digraph { Inizio -> Fine }
```

$$\int_0^1 x\,dx = \tfrac12$$
FINE
    SINCE=$(date "+%Y-%m-%d %H:%M:%S")
    (qlmanage -p "$DIAGRAM" >/dev/null 2>&1 &)
    sleep 8
    pkill -x qlmanage >/dev/null 2>&1
    /usr/bin/log show --start "$SINCE" --info --debug \
        --predicate 'process == "MacDownQuickLook"' --style compact \
        > "$WORK/diagrams.log" 2>/dev/null

    # Which copy actually answered. Two extensions with the *same* bundle
    # identifier — the installed one and the one just built — cannot be
    # told apart by pluginkit, and macOS picks by path: saying so is better
    # than passing or failing on somebody else's code.
    SERVED=$(sed -n 's/.*"CFBundleExecutablePath"="\([^"]*\)".*/\1/p' \
             "$WORK/diagrams.log" | head -1)
    case "$SERVED" in
        "$APP"/*)
            ok "legge le preferenze dell'applicazione (le formule sono una)" \
                grep -q "maths: com\." "$WORK/diagrams.log"
            # Whether the formula counts depends on that preference, and the
            # suite does not touch somebody's settings to make a check pass.
            if grep -q "so flags 0$" "$WORK/diagrams.log"; then
                ok "mermaid e Graphviz vengono disegnati (formule spente)" \
                    contains "$WORK/diagrams.log" "drawn 2 of 2"
            else
                ok "mermaid, Graphviz e la formula vengono disegnati" \
                    contains "$WORK/diagrams.log" "drawn 3 of 3"
            fi ;;
        *)
            skip "i disegni — ha risposto ${SERVED:-una copia sconosciuta}" ;;
    esac
fi

# Whatever was ignored to make room for the copy under test goes back.
restore_extensions


# ------------------------------------------- what the two panes say to each other

# The unit tests drive the page script with hand-written HTML and the
# mapping with hand-written source. This is the whole path on a real
# document, rendered by the real renderer, in a real web view: the part
# nobody can try by reading it.

say "La selezione fra i due pannelli"

DOC_SEL="$WORK/selezione.md"
cat > "$DOC_SEL" <<'FINE'
# Verbale di prova

Un test qui, e un altro test più in là, nello stesso paragrafo.

- Primo punto dell'elenco
- Secondo punto dell'elenco

Questo paragrafo ha del **grassetto** in mezzo, e finisce qui.
FINE

if clang -fobjc-arc -framework Cocoa -framework WebKit \
         -IMacDown/Code/Utility -IDependency/hoedown/src \
         -o "$WORK/selection_probe" Tools/selection_probe.m \
         MacDown/Code/Utility/MPPreviewSelection.m \
         Dependency/hoedown/src/*.c > "$WORK/probe.log" 2>&1
then
    probe() { "$WORK/selection_probe" "$DOC_SEL" "$@" > "$WORK/probe.out" 2>&1; }

    ok "una parola scelta nella pagina si ritrova nel sorgente" \
        probe pick "Un test qui"
    ok "e in una voce di elenco, che prima non riportava niente" \
        probe pick "Primo punto"
    # The second "test" of a paragraph is the second one, not the first:
    # the page says how far into its own text the selection began.
    probe pick "test" 2
    ok "la seconda occorrenza è la seconda" \
        contains "$WORK/probe.out" "a 44"
    ok "una selezione che attraversa un'enfasi porta con sé i marcatori" \
        grep -q "«del \*\*grassetto\*\* in mezzo»" \
        <(probe pick "del grassetto in mezzo"; cat "$WORK/probe.out")
    ok "parole che nella pagina non ci sono non si piazzano" \
        sh -c '! "$0" "$1" pick "queste parole non esistono" >/dev/null 2>&1' \
        "$WORK/selection_probe" "$DOC_SEL"
    # And the other way: the editor has a selection, the page marks it.
    ok "il verso opposto: la pagina segna quello che l'editor seleziona" \
        probe show "del **grassetto** in mezzo"
    ok "e quello che il sorgente ha e la pagina no resta senza segno" \
        sh -c '! "$0" "$1" show "*sottolineato*" >/dev/null 2>&1' \
        "$WORK/selection_probe" "$DOC_SEL"
else
    skip "il banco della selezione non si è compilato — $WORK/probe.log"
fi


# --------------------------------------------- a diagram from a description

# The sheet draws what the model wrote with the application's own copy of
# mermaid, and refuses to put a diagram in the document until it has drawn.
# Both halves are checked here: the library is where the sheet looks for it,
# and the preview pane's copy is the same one.

say "Il diagramma da una descrizione"

ok "mermaid viaggia nell'app, dove il pannello lo cerca" \
    test -f "$APP/Contents/Resources/Extensions/mermaid.min.js"
ok "ed è la stessa copia che disegna l'anteprima" \
    cmp -s "$APP/Contents/Resources/Extensions/mermaid.min.js" \
        MacDown/Resources/Extensions/mermaid.min.js


# ------------------------------------------------------- comparing two files

# The window cannot be driven from a script, but what it draws comes from
# one pure function, and that function can be asked about real files.

say "Il confronto fra due documenti"

DIFF_A="$WORK/a.md"
DIFF_B="$WORK/b.md"
printf '# Verbale\n\nPresenti: Anna.\n\n- una cosa\n' > "$DIFF_A"
printf '# Verbale\n\nPresenti: Anna, Bruno.\n\n- una cosa\n- e un altra\n' \
    > "$DIFF_B"

DIFF_PROBE="$WORK/diff_probe"
if clang -fobjc-arc -framework Foundation -IMacDown/Code/Utility \
        -o "$DIFF_PROBE" Tools/diff_probe.m MacDown/Code/Utility/MPDiff.m \
        > "$WORK/diff.log" 2>&1
then
    ok "una riga cambiata è una riga, non due" \
        sh -c '[ "$("$0" "$1" "$2")" = "==~==+" ]' \
        "$DIFF_PROBE" "$DIFF_A" "$DIFF_B"
    ok "due file uguali non hanno differenze" \
        sh -c '[ "$("$0" "$1" "$1" --counts)" = "0 cambiate, 0 aggiunte, 0 tolte" ]' \
        "$DIFF_PROBE" "$DIFF_A"
    ok "e al contrario, quello che era aggiunto è tolto" \
        sh -c '[ "$("$0" "$2" "$1" --counts)" = "1 cambiate, 0 aggiunte, 1 tolte" ]' \
        "$DIFF_PROBE" "$DIFF_A" "$DIFF_B"
    ok "un file che non è testo si rifiuta invece di rispondere" \
        sh -c '! "$0" "$1" /bin/ls >/dev/null 2>&1' \
        "$DIFF_PROBE" "$DIFF_A"

    # The measurement the paragraph grain exists for: the same words, gone
    # to the line in another place.
    printf '# Nota\n\nUna frase lunga che sta\nsu due righe intere.\n' \
        > "$WORK/w-a.md"
    printf '# Nota\n\nUna frase lunga\nche sta su due\nrighe intere.\n' \
        > "$WORK/w-b.md"
    ok "riavvolgere un documento, per righe, lo cambia tutto" \
        sh -c '[ "$("$0" "$1" "$2" --counts)" != "0 cambiate, 0 aggiunte, 0 tolte" ]' \
        "$DIFF_PROBE" "$WORK/w-a.md" "$WORK/w-b.md"
    ok "e per paragrafi non lo cambia affatto" \
        sh -c '[ "$("$0" "$1" "$2" --counts --paragraphs)" = "0 cambiate, 0 aggiunte, 0 tolte" ]' \
        "$DIFF_PROBE" "$WORK/w-a.md" "$WORK/w-b.md"

    printf 'Una riga  con   spazi\nSECONDA\n' > "$WORK/s-a.md"
    printf '  Una riga con spazi\nseconda\n' > "$WORK/s-b.md"
    ok "gli spazi si possono ignorare" \
        sh -c '[ "$("$0" "$1" "$2" --counts --ignore-space)" = "1 cambiate, 0 aggiunte, 0 tolte" ]' \
        "$DIFF_PROBE" "$WORK/s-a.md" "$WORK/s-b.md"
    # A menu item that points at a selector nobody implements looks fine
    # until somebody clicks it: the nib and the binary are asked together.
    menu_and_code_agree() {
        local selector="$1"
        strings "$APP/Contents/Resources/Base.lproj/MainMenu.nib" \
            | grep -q "$selector" || return 1
        strings "$APP/Contents/MacOS/"* | grep -q "$selector"
    }
    ok "«con la copia sul disco» è nel menu e nel codice" \
        menu_and_code_agree compareWithSavedFile:
    ok "«con una versione» pure" \
        menu_and_code_agree compareWithVersion:

    ok "e le maiuscole pure" \
        sh -c '[ "$("$0" "$1" "$2" --counts --ignore-space --ignore-case)" = "0 cambiate, 0 aggiunte, 0 tolte" ]' \
        "$DIFF_PROBE" "$WORK/s-a.md" "$WORK/s-b.md"
else
    skip "il banco del confronto non si è compilato — $WORK/diff.log"
fi


# ----------------------------------------------------------- the MCP server

# The unit tests talk to the server's classes; this talks to the binary the
# way an assistant would — one pipe, one conversation — and asks it the two
# questions that matter outside the code: does it travel inside the app, and
# does it say no to a path outside the folder it was given.

say "Il server MCP"

MCP="$APP/Contents/SharedSupport/bin/macdownext-mcp"
ok "il server viaggia nell'app" test -x "$MCP"

if [ -x "$MCP" ]; then
    MCP_ROOT="$WORK/note"
    mkdir -p "$MCP_ROOT"
    printf '# Relazione\n\nUna riga con la parola cardine.\n' \
        > "$MCP_ROOT/relazione.md"
    mkdir -p "$MCP_ROOT/sotto"
    printf -- '---\ntags: [iso]\nstato: aperto\n---\n\n# Indice\n\n%s\n' \
        'Vedi [la relazione](../relazione.md).' \
        > "$MCP_ROOT/sotto/indice.md"
    # The server reads lines until the pipe closes, so the whole
    # conversation goes in at once and the answers come out in order.
    {
        printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"suite","version":"1"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
        printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"search","arguments":{"query":"cardine"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"read","arguments":{"path":"../fuori.md"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"write","arguments":{"path":"relazione.md","text":"altro"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"backlinks","arguments":{"path":"relazione.md"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"frontmatter","arguments":{"path":"sotto/indice.md"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"find_by_field","arguments":{"field":"stato","value":"aperto"}}}'
    } | "$MCP" --root "$MCP_ROOT" > "$WORK/mcp.out" 2> "$WORK/mcp.err"

    ok "risponde alla stretta di mano" \
        contains "$WORK/mcp.out" '"protocolVersion":"2025-06-18"'
    ok "si presenta col suo nome" \
        contains "$WORK/mcp.out" '"name":"macdownext-mcp"'
    ok "dichiara i sette arnesi" \
        sh -c '[ "$(grep -o "\"name\":\"\(search\|read\|list\|outline\|backlinks\|frontmatter\|find_by_field\)\"" "$0" | sort -u | wc -l)" -eq 7 ]' \
        "$WORK/mcp.out"
    ok "trova una parola nei documenti della cartella" \
        contains "$WORK/mcp.out" "relazione.md"
    ok "rifiuta un percorso fuori dalla radice" \
        contains "$WORK/mcp.out" \
        "that path is outside the folders this server was given"
    ok "in sola lettura non esiste un arnese che scriva" \
        contains "$WORK/mcp.out" "there is no tool called write"
    ok "e non sporca il documento" \
        grep -q "parola cardine" "$MCP_ROOT/relazione.md"
    # The three of phase two, in the same conversation: who cites a
    # document, what a document declares, and which documents declare it.
    ok "dice chi cita un documento, e da quale sottocartella" \
        contains "$WORK/mcp.out" 'sotto/indice.md'
    ok "legge il front matter come mappa" \
        contains "$WORK/mcp.out" '\"stato\":\"aperto\"'
    ok "trova i documenti che dichiarano un campo" \
        contains "$WORK/mcp.out" '\"field\":\"stato\"'

    # And phase three, which is the half that can do damage: a second
    # conversation, started with --write, that makes a document, adds to it
    # and changes a line — and a third, read-only, that refuses to.
    MCP_LOG="$WORK/mcp.log"
    {
        printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"suite","version":"1"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
        printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"create","arguments":{"path":"nuovo.md","text":"# Nuovo\n\nUna riga."}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"append","arguments":{"path":"nuovo.md","text":"In coda."}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"replace","arguments":{"path":"nuovo.md","find":"Una riga.","with":"Un altra riga."}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"create","arguments":{"path":"nuovo.md","text":"sopra"}}}'
    } | "$MCP" --root "$MCP_ROOT" --write --log "$MCP_LOG" \
        > "$WORK/mcp-write.out" 2>&1

    ok "col permesso di scrivere dichiara dieci arnesi" \
        sh -c '[ "$(grep -o "\"name\":\"\(search\|read\|list\|outline\|backlinks\|frontmatter\|find_by_field\|append\|create\|replace\)\"" "$0" | sort -u | wc -l)" -eq 10 ]' \
        "$WORK/mcp-write.out"
    ok "crea un documento che non c'era" test -f "$MCP_ROOT/nuovo.md"
    ok "aggiunge in coda e sostituisce quello che trova" \
        sh -c 'grep -q "Un altra riga." "$0" && grep -q "In coda." "$0"' \
        "$MCP_ROOT/nuovo.md"
    ok "e rifiuta di scrivere sopra un file che c'è già" \
        contains "$WORK/mcp-write.out" "writes over nothing"
    # The diary is the answer to «chi ha toccato questo file», so it has to
    # hold the refusals as well as the changes.
    ok "scrive ogni chiamata nel diario" \
        sh -c 'grep -q "create .*ok" "$0" && grep -q "create .*refused" "$0"' \
        "$MCP_LOG"

    printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"suite","version":"1"}}}' \
        '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"append","arguments":{"path":"relazione.md","text":"di nascosto"}}}' \
        | "$MCP" --root "$MCP_ROOT" --no-log > "$WORK/mcp-ro.out" 2>&1
    ok "senza permesso non aggiunge niente a niente" \
        contains "$WORK/mcp-ro.out" "not started with permission"
    ok "e la relazione è rimasta quella" \
        sh -c '! grep -q "di nascosto" "$0"' "$MCP_ROOT/relazione.md"

    # Two things a client can send that used to end the conversation: a
    # textbundle whose text points out of the folder, and an argument of the
    # wrong kind. Both in one conversation, with a real call after them, so
    # that a server that fell over fails the check.
    mkdir -p "$MCP_ROOT/trappola.textbundle"
    printf '{"version":2,"type":"net.daringfireball.markdown"}' \
        > "$MCP_ROOT/trappola.textbundle/info.json"
    ln -sf /etc/hosts "$MCP_ROOT/trappola.textbundle/text.markdown"
    {
        printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"suite","version":"1"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"read","arguments":{"path":"trappola.textbundle"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"search","arguments":{"query":"localhost"}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"read","arguments":{"path":42}}}'
        printf '%s\n' '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":[1,2]}'
        printf '%s\n' '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"read","arguments":{"path":"relazione.md"}}}'
    } | "$MCP" --root "$MCP_ROOT" --no-log > "$WORK/mcp-attacco.out" 2>&1
    rm -rf "$MCP_ROOT/trappola.textbundle"

    ok "un pacchetto il cui testo punta fuori è fuori" \
        sh -c 'grep -q "\"id\":2" "$0" && grep -q "outside the folders" "$0" \
               && ! grep -q "Host Database" "$0"' "$WORK/mcp-attacco.out"
    ok "e la ricerca non lo legge lo stesso" \
        sh -c '! grep -q "localhost is used" "$0"' "$WORK/mcp-attacco.out"
    ok "un argomento del tipo sbagliato è un rifiuto, non una caduta" \
        contains "$WORK/mcp-attacco.out" "path has to be text"
    ok "e dopo tutto questo risponde ancora" \
        sh -c 'grep -q "\"id\":6" "$0"' "$WORK/mcp-attacco.out"

    # The switch in Settings ▸ Agents is the one thing about this server the
    # application decides, so it is asked the way a person would: turn it
    # off, start the server, and see it refuse.
    MCP_DOMAIN=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
        "$APP/Contents/Info.plist" 2>/dev/null)
    mcp_hello() {
        printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"suite","version":"1"}}}' \
            | "$MCP" --root "$MCP_ROOT" --no-log > "$1" 2>&1
    }
    if [ -n "$MCP_DOMAIN" ]; then
        MCP_WAS=$(defaults read "$MCP_DOMAIN" agentsAllowed 2>/dev/null)
        defaults write "$MCP_DOMAIN" agentsAllowed -bool NO
        mcp_hello "$WORK/mcp-off.out"
        ok "spento dalle impostazioni, il server non parte" \
            contains "$WORK/mcp-off.out" "assistenti sono spenti"

        # Put the switch back the way it was found, whatever happens next.
        case "$MCP_WAS" in
            1) defaults write "$MCP_DOMAIN" agentsAllowed -bool YES ;;
            0) defaults write "$MCP_DOMAIN" agentsAllowed -bool NO ;;
            *) defaults delete "$MCP_DOMAIN" agentsAllowed 2>/dev/null ;;
        esac
        # Whatever it was, the server has to come back: a suite that leaves
        # assistants switched off would fail every run after this one.
        defaults read "$MCP_DOMAIN" agentsAllowed 2>/dev/null | grep -q 0 \
            && defaults delete "$MCP_DOMAIN" agentsAllowed 2>/dev/null
        mcp_hello "$WORK/mcp-on.out"
        ok "e riacceso riparte" \
            contains "$WORK/mcp-on.out" "macdownext-mcp"
    else
        skip "l'interruttore degli agenti (manca l'identificativo dell'app)"
    fi
fi


# ------------------------------------------------------------------ Italian

# A string with no translation shows the reader the key, and a nib object
# with no translation shows the reader English inside an Italian menu. Both
# are invisible to a build and to XCTest, so they are counted here.

# ------------------------------------------------------ colour, and the rest

# `[testo]{...}` is rewritten before the parser sees it. Two things are
# worth checking on the built products rather than in XCTest: that the
# Finder extension carries the same rewriting as the application — a
# colour that shows in the editor and not in the preview is the kind of
# difference nobody notices until somebody else opens the file — and that
# what it refuses is still refused.

say "Il colore delle parole"

ok "l'applicazione porta la riscrittura" \
    sh -c 'nm -u "$0" > /dev/null 2>&1;
           nm "$0" 2>/dev/null | grep -q MPMarkdownWithAttributedSpans' \
    "$APP/Contents/MacOS/MacDown Next"
ok "e l'estensione dell'anteprima la stessa" \
    sh -c 'nm "$0" 2>/dev/null | grep -q MPMarkdownWithAttributedSpans' \
    "$APPEX/Contents/MacOS/MacDownQuickLook"
ok "il menu contestuale offre di scegliere un colore" \
    contains MacDown/Code/View/MPEditorView.m "chooseHighlightForSelection:"
# In the editor the span is treated as the other markup is: the braces are
# hidden until the caret arrives, and the words are painted. Both are in
# the application's binary, and neither has a preference of its own.
ok "nell'editor le graffe si nascondono come il resto dei marcatori" \
    contains MacDown/Code/View/MPMarkerHider.m "addAttributedSpans:"
ok "e le parole prendono il colore che chiedono" \
    sh -c 'nm "$0" 2>/dev/null | grep -q MPColourFromCSS' \
    "$APP/Contents/MacOS/MacDown Next"
ok "e la dimensione aspetta che le graffe siano nascoste" \
    contains MacDown/Code/View/MPSpanStyler.m "isDrawnAsMeaning:"

if clang -fobjc-arc -framework Foundation \
         -I MacDown/Code/Utility -o "$WORK/spans" \
         Tools/spans_probe.m MacDown/Code/Utility/MPAttributedSpans.m \
         MacDown/Code/Utility/MPMarkdownText.m > /dev/null 2>&1; then
    ok "una parola col colore diventa una span" \
        sh -c '[ "$("$0" "Una [parola]{style=\"color:#c00\"} qui")" \
               = "Una <span style=\"color:#c00\">parola</span> qui" ]' \
        "$WORK/spans"
    ok "un gestore di eventi resta scritto, non diventa niente" \
        sh -c '[ "$("$0" "[x]{onclick=\"alert(1)\"}")" \
               = "[x]{onclick=\"alert(1)\"}" ]' "$WORK/spans"
    ok "uno stile che andrebbe a prendere qualcosa neanche" \
        sh -c '[ "$("$0" "[x]{style=\"background:url(http://e.it)\"}")" \
               = "[x]{style=\"background:url(http://e.it)\"}" ]' "$WORK/spans"
    ok "un collegamento resta un collegamento" \
        sh -c '[ "$("$0" "[testo](http://e.it)")" = "[testo](http://e.it)" ]' \
        "$WORK/spans"
    ok "quello che scavalca un paragrafo non è una span" \
        sh -c '[ "$("$0" "[uno

due]{style=\"color:red\"}")" = "[uno

due]{style=\"color:red\"}" ]' "$WORK/spans"
    ok "una parola con lo sfondo e la dimensione arriva intera" \
        sh -c '[ "$("$0" "[x]{style=\"background-color:#ff0;font-size:1.5em\"}")" \
               = "<span style=\"background-color:#ff0;font-size:1.5em\">x</span>" ]' \
        "$WORK/spans"
else
    skip "la riscrittura provata a parte (clang non ha costruito l'arnese)"
fi


# ------------------------------------------------- importing a Word document

# The conversion is asked about XML by the plug-in's own suite; here the
# question is the one that suite cannot ask — whether the plug-in the
# application actually ships opens a real archive.

say "L'importazione di un documento"

IMPORT="$APP/Contents/PlugIns/DocumentImport.plugin"
ok "il plug-in viaggia nell'app" test -d "$IMPORT"
ok "e non chiede di essere installato a parte" \
    test -x "$IMPORT/Contents/MacOS/DocumentImport"
ok "le sue voci stanno in Archivio, non nel menu dei plug-in" \
    contains plugins/DocumentImport/DocumentImport.m "placesItsOwnMenuItem"

ok "il convertitore risponde delle proprie prove" \
    bash plugins/DocumentImport/tests/run.sh

# A real .docx, built here: a zip with the parts Word writes. What the
# plug-in does with it — unzip, read, convert — is what a person does.
DOCX="$WORK/docx"
mkdir -p "$DOCX/word/_rels" "$DOCX/_rels"
cp plugins/DocumentImport/tests/word-document.xml "$DOCX/word/document.xml"
cp plugins/DocumentImport/tests/word-rels.xml "$DOCX/word/_rels/document.xml.rels"
cp plugins/DocumentImport/tests/word-numbering.xml "$DOCX/word/numbering.xml"
# Written as Word writes it in Italian: the style is «Titolo1» and only
# styles.xml knows that means a heading.
cp plugins/DocumentImport/tests/word-italiano.xml "$DOCX/word/document.xml"
cp plugins/DocumentImport/tests/word-styles.xml "$DOCX/word/styles.xml"
printf '<?xml version="1.0"?><Relationships/>' > "$DOCX/_rels/.rels"
(cd "$DOCX" && zip -q -r "$WORK/verbale.docx" .)

ok "un .docx vero è un archivio che unzip apre" \
    unzip -t "$WORK/verbale.docx"

unzip -q -o "$WORK/verbale.docx" -d "$WORK/aperto" 2>/dev/null
if command -v clang > /dev/null 2>&1 \
        && clang -fobjc-arc -framework Foundation \
            -I plugins/DocumentImport \
            -o "$WORK/import-probe" \
            plugins/DocumentImport/tests/harness.m \
            plugins/DocumentImport/MDOfficeImport.m > /dev/null 2>&1; then
    "$WORK/import-probe" --word "$WORK/aperto/word/document.xml" \
        "$WORK/aperto/word/_rels/document.xml.rels" \
        "$WORK/aperto/word/numbering.xml" \
        "$WORK/aperto/word/styles.xml" > "$WORK/importato.md" 2>/dev/null
    ok "e i titoli di un documento italiano sono titoli" \
        sh -c 'grep -qxF "# Relazione annuale" "$0" \
               && grep -qxF "## Un sottotitolo" "$0"' "$WORK/importato.md"
    ok "senza scrivere il grassetto due volte" \
        sh -c '! grep -q "^# \*\*" "$0"' "$WORK/importato.md"

    # And the older fixture, which is the one with lists and pictures.
    "$WORK/import-probe" --word plugins/DocumentImport/tests/word-document.xml \
        plugins/DocumentImport/tests/word-rels.xml \
        plugins/DocumentImport/tests/word-numbering.xml \
        > "$WORK/importato2.md" 2>/dev/null
    ok "e quello che ne esce è il documento, in Markdown" \
        contains "$WORK/importato2.md" "# Verbale della riunione"
    ok "con gli elenchi ancora due" \
        sh -c 'grep -q "^- Si adotta" "$0" && grep -q "^1\. Primo passo" "$0"' \
        "$WORK/importato2.md"
    ok "e l'immagine collegata dove sarà scritta" \
        contains "$WORK/importato2.md" "](media/rete.png)"
else
    skip "la conversione di un .docx vero (clang non ha costruito l'arnese)"
fi


say "Traduzione"

ok "ogni stringa inglese ha la sua traduzione italiana, e i nib pure" \
    python3 Tools/check_translations.py

italian_parses() {
    local file
    for file in MacDown/Localization/it-IT.lproj/*.strings; do
        [ -s "$file" ] || continue     # MPDocument.strings is empty on purpose
        plutil -lint "$file" >/dev/null 2>&1 || return 1
    done
    return 0
}
ok "i file italiani si leggono come property list" italian_parses

# A .strings file inside a bundle is not yet a translation the reader gets:
# the folder has to be an .lproj the loader recognizes, and the key has to
# match to the last character. This asks the bundles the same question the
# interface asks them.
LOCALIZED="$WORK/localized_string"
if clang -fobjc-arc -framework Foundation -o "$LOCALIZED" \
        Tools/localized_string.m 2>/dev/null; then
    ok "l'applicazione risponde in italiano" \
        "$LOCALIZED" "$APP" it-IT "Check for Updates…"
    ok "l'estensione dell'anteprima porta le sue traduzioni" \
        "$LOCALIZED" "$APPEX" it-IT \
        $'\n\n---\n\n*The document is too long: only the beginning is shown here.*\n'
    ok "Drawio.plugin porta le sue traduzioni" \
        "$LOCALIZED" "$APP/Contents/PlugIns/Drawio.plugin" it-IT \
        "Import a draw.io Diagram…"
    # Built by its own script, on purpose: a plug-in needs no Xcode target.
    [ -d plugins/LoremIpsum/LoremIpsum.plugin ] \
        || bash plugins/LoremIpsum/build.sh >/dev/null 2>&1
    ok "LoremIpsum.plugin porta le sue traduzioni" \
        "$LOCALIZED" plugins/LoremIpsum/LoremIpsum.plugin it-IT \
        "Insert Sample Text"
    ok "DocumentImport.plugin porta le sue traduzioni" \
        "$LOCALIZED" "$APP/Contents/PlugIns/DocumentImport.plugin" it-IT \
        "Word Document (.docx)…"
else
    skip "le traduzioni a runtime (clang non ha costruito l'arnese)"
fi


# -------------------------------------------------------------- the verdict

say "Esito"
printf '  %d passate, %d fallite' "$PASSED" "$FAILED"
[ "$SKIPPED" -gt 0 ] && printf ', %d saltate' "$SKIPPED"
printf '\n\n'
exit "$FAILED"
