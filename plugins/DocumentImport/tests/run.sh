#!/bin/bash
#
# The conversion, asked about two documents and about the things that go
# wrong. No window and no plug-in: the half that turns XML into Markdown is
# a function, and this builds it on its own and talks to it.
#
#   tests/run.sh            the checks
#   tests/run.sh --show     and what came out, to read
#
# Exit status is the number of failures, so it is usable from a script.
set -o nounset
set -o pipefail

cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SHOW=${1:-}
PASSED=0
FAILED=0

ok() {
    local what="$1"; shift
    if "$@" > /dev/null 2>&1; then
        printf '  \033[32m✓\033[0m %s\n' "$what"
        PASSED=$((PASSED + 1))
    else
        printf '  \033[31m✗\033[0m %s\n' "$what"
        FAILED=$((FAILED + 1))
    fi
}

if ! clang -fobjc-arc -framework Foundation -I. \
        -o "$WORK/harness" tests/harness.m MDOfficeImport.m \
        > "$WORK/build.log" 2>&1; then
    echo "il banco non si è compilato:"
    cat "$WORK/build.log"
    exit 1
fi

echo "Il convertitore"

"$WORK/harness" --word tests/word-document.xml tests/word-rels.xml \
    tests/word-numbering.xml > "$WORK/word.md" 2> "$WORK/word.err"
"$WORK/harness" --odt tests/odt-content.xml \
    > "$WORK/odt.md" 2> "$WORK/odt.err"
# The same document twice: with the styles Word ships, and without them.
"$WORK/harness" --word tests/word-italiano.xml "" "" tests/word-styles.xml \
    > "$WORK/italiano.md" 2> /dev/null
"$WORK/harness" --word tests/word-italiano.xml \
    > "$WORK/senza-stili.md" 2> /dev/null

if [ "$SHOW" = "--show" ]; then
    echo "--- da .docx ---"; cat "$WORK/word.md"
    echo "--- da .odt ---";  cat "$WORK/odt.md"
fi

ok "un documento Word diventa quel Markdown" \
    diff -q tests/word-expected.md "$WORK/word.md"
ok "un OpenDocument diventa quel Markdown" \
    diff -q tests/odt-expected.md "$WORK/odt.md"

# The two fixtures are not the same document — each shows off what its own
# format can do — but the parts they share have to come out the same.
ok "le parti in comune escono uguali dai due formati" \
    sh -c 'for line in "# Verbale della riunione" "## Decisioni" \
                       "| Sottosistema | Stato |" \
                       "> La misura che conta non è quanto va veloce."; do
               grep -qxF "$line" "$0" || exit 1
               grep -qxF "$line" "$1" || exit 1
           done' \
    "$WORK/word.md" "$WORK/odt.md"

# Word names its styles in whatever language it was in — Titolo1,
# Überschrift1 — and only styles.xml carries the English name and the
# outline level that say «this is a heading». Without it a document in any
# other language came out with its headings as bold paragraphs.
ok "i titoli di un documento italiano sono titoli" \
    diff -q tests/word-italiano-expected.md "$WORK/italiano.md"
ok "un livello scritto nello stile lo dice anche senza nome" \
    grep -qxF "## Un sottotitolo" "$WORK/italiano.md"
ok "e uno stile basato su un altro eredita la profondità" \
    grep -qxF "## Basato su Titolo2" "$WORK/italiano.md"
ok "un livello messo a mano sul paragrafo vale lo stesso" \
    grep -qxF "### Fatto a mano" "$WORK/italiano.md"
ok "il grassetto di un titolo non si scrive due volte" \
    sh -c '! grep -q "^# \*\*" "$0"' "$WORK/italiano.md"
ok "ma quello dentro un paragrafo resta" \
    grep -qF "**una parola in grassetto**" "$WORK/italiano.md"
ok "e un paragrafo tutto in grassetto resta grassetto" \
    grep -qxF "**Un paragrafo tutto in grassetto**" "$WORK/italiano.md"
# The bug, kept as a check: this is what the reader saw, and what says
# the styles are not optional.
ok "senza gli stili quei titoli sarebbero paragrafi in grassetto" \
    grep -qxF "**Relazione annuale**" "$WORK/senza-stili.md"

ok "le immagini sono elencate col loro nome" \
    grep -q "picture.*rete.png" "$WORK/word.err"
ok "e anche dall'OpenDocument" \
    grep -q "picture.*Pictures/rete.png" "$WORK/odt.err"

ok "il grassetto e il corsivo arrivano" \
    grep -q '\*\*Anna\*\*, \*Bruno\*' "$WORK/word.md"
ok "l'elenco puntato e quello numerato restano due elenchi" \
    sh -c 'grep -q "^- Si adotta" "$0" && grep -q "^1\. Primo passo" "$0"' \
    "$WORK/word.md"
ok "una tabella è una tabella" \
    grep -q "^| Sottosistema | Stato |" "$WORK/word.md"
ok "gli asterischi del testo vengono protetti" \
    grep -q 'asterisco \\\*' "$WORK/word.md"
ok "il barrato e il codice arrivano dall'OpenDocument" \
    sh -c 'grep -q "~~questo no~~" "$0" && grep -q "`codice()`" "$0"' \
    "$WORK/odt.md"

# What it does when the document is not what it says it is.
printf 'non sono xml\n' > "$WORK/rotto.xml"
ok "un file che non è XML non fa cadere niente" \
    sh -c '"$0" --word "$1" > /dev/null 2>&1' "$WORK/harness" "$WORK/rotto.xml"
ok "e lo dice invece di inventare" \
    sh -c '"$0" --word "$1" 2>&1 >/dev/null | grep -q "lost"' \
    "$WORK/harness" "$WORK/rotto.xml"
printf '<?xml version="1.0"?><a/>\n' > "$WORK/vuoto.xml"
ok "un XML che non è un documento dà niente, non spazzatura" \
    sh -c '[ -z "$("$0" --odt "$1" 2>/dev/null)" ]' "$WORK/harness" "$WORK/vuoto.xml"

printf '\n  %d passate, %d fallite\n\n' "$PASSED" "$FAILED"
exit "$FAILED"
