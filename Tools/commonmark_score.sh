#!/bin/bash
#
# Quanta parte di CommonMark il parser dell'applicazione rende come la
# specifica dice. Il numero che sta in docs/studio-commonmark.md, rifatto.
#
#   Tools/commonmark_score.sh              # i tre conteggi e le sezioni
#   Tools/commonmark_score.sh --esempi 5   # e cinque esempi falliti per sezione
#
# Gli esempi vengono da spec.json della specifica: si scarica una volta e
# resta in Tools/.cache. Senza rete e senza copia, lo dice e si ferma.
set -o nounset
set -o pipefail

cd "$(dirname "$0")/.."
VERSION=0.31.2
CACHE="Tools/.cache"
SPEC="$CACHE/commonmark-$VERSION.json"
SHOW=0
[ "${1:-}" = "--esempi" ] && SHOW="${2:-3}"

mkdir -p "$CACHE"
if [ ! -s "$SPEC" ]; then
    echo "scarico gli esempi della specifica $VERSION…"
    curl -sfL "https://spec.commonmark.org/$VERSION/spec.json" -o "$SPEC" || {
        rm -f "$SPEC"
        echo "non si è potuto scaricare spec.json, e non ce n'è una copia." >&2
        exit 1
    }
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if ! clang -O2 -I Dependency/hoedown/src -o "$WORK/probe" \
        Tools/commonmark_probe.c Dependency/hoedown/src/*.c \
        > "$WORK/build.log" 2>&1; then
    echo "il banco non si è compilato:" >&2
    cat "$WORK/build.log" >&2
    exit 1
fi
cp "$WORK/probe" "$WORK/probe-x"

python3 - "$SPEC" "$WORK/probe" "$SHOW" <<'PY'
import json, re, subprocess, sys, collections

spec = json.load(open(sys.argv[1]))
probe = sys.argv[2]
show = int(sys.argv[3])
ours = re.compile(r' data-src="\d+"')


def clean(html, spaces=False, closing=False):
    """L'HTML senza quello che non riguarda la conformità."""
    html = ours.sub('', html)            # data-src è nostro, non della specifica
    if spaces:
        html = re.sub(r'\s+', ' ', html).strip()
    if closing:
        html = re.sub(r'\s*/>', '/>', html)
    return html


def render(markdown, xhtml=False):
    args = [probe] + (['--xhtml'] if xhtml else [])
    return subprocess.run(args, input=markdown, capture_output=True,
                          text=True).stdout


exact = loose = generous = 0
failed = collections.Counter()
tried = collections.Counter()
examples = collections.defaultdict(list)

for one in spec:
    tried[one['section']] += 1
    got = render(one['markdown'])
    want = one['html']
    if clean(got) == want:
        exact += 1
    if clean(got, spaces=True) == clean(want, spaces=True):
        loose += 1
    if clean(render(one['markdown'], True), True, True) == clean(want, True, True):
        generous += 1
    else:
        failed[one['section']] += 1
        examples[one['section']].append((one['example'], one['markdown'],
                                         want, clean(got)))

total = len(spec)
print()
print("  esatto, com'esce dall'applicazione      %3d / %d  (%.0f%%)"
      % (exact, total, 100.0 * exact / total))
print("  ignorando gli spazi bianchi             %3d / %d  (%.0f%%)"
      % (loose, total, 100.0 * loose / total))
print("  il più generoso possibile               %3d / %d  (%.0f%%)"
      % (generous, total, 100.0 * generous / total))
print()
print("  %-42s %5s %6s" % ("sezione", "prove", "fall."))
for section in sorted(tried, key=lambda s: (-failed[s], s)):
    if not failed[section]:
        continue
    print("  %-42s %5d %6d  %s" % (section, tried[section], failed[section],
          "█" * int(round(20.0 * failed[section] / tried[section]))))

whole = sorted(s for s in tried if not failed[s])
print()
print("  senza un solo errore: %s" % (", ".join(whole) or "nessuna sezione"))

if show:
    for section in sorted(examples, key=lambda s: -failed[s]):
        print("\n  --- %s" % section)
        for number, markdown, want, got in examples[section][:show]:
            print("  esempio %d" % number)
            print("    md       %s" % markdown.replace("\n", "\\n")[:100])
            print("    atteso   %s" % want.replace("\n", " ")[:100])
            print("    hoedown  %s" % got.replace("\n", " ")[:100])
print()
PY
