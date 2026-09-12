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
