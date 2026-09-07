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

Un paragrafo con **grassetto** e un [collegamento](altro.md).

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


# ------------------------------------------------------------------ Italian

# A string with no translation shows the reader the key, and a nib object
# with no translation shows the reader English inside an Italian menu. Both
# are invisible to a build and to XCTest, so they are counted here.

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
else
    skip "le traduzioni a runtime (clang non ha costruito l'arnese)"
fi


# -------------------------------------------------------------- the verdict

say "Esito"
printf '  %d passate, %d fallite' "$PASSED" "$FAILED"
[ "$SKIPPED" -gt 0 ] && printf ', %d saltate' "$SKIPPED"
printf '\n\n'
exit "$FAILED"
