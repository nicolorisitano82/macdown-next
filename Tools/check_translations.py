#!/usr/bin/env python3
"""Tools/check_translations.py — what is translated, and what is not.

Reads every NSLocalizedString in the sources and every .strings file in the
localizations, and says three things:

  * which keys the code asks for and no language file answers — those show
    the reader the key itself;
  * which of those keys are written in Italian rather than English, which is
    why they *look* fine in Italian and appear as Italian in every other
    language;
  * which nib objects the base nib has and a translation does not.

Exit status is the number of strings a reader would see untranslated in the
interface's own language, so it is usable from a script.

    Tools/check_translations.py            # the summary
    Tools/check_translations.py --list     # and every string, by category
    Tools/check_translations.py --lang de  # one language in full
"""

import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALIZATIONS = os.path.join(ROOT, "MacDown", "Localization")
SOURCES = [
    os.path.join(ROOT, "MacDown", "Code"),
    os.path.join(ROOT, "QuickLook"),
    os.path.join(ROOT, "plugins"),
]

# The language the sources are written in, and the one this fork writes its
# newer strings in.
BASE = "Base"
ENGLISH = "en"
ITALIAN = "it-IT"

# NSLocalizedString(@"…", @"…") over several lines, with the escapes and the
# adjacent-literal concatenation Objective-C allows.
CALL = re.compile(
    r'NSLocalizedString\s*\(\s*((?:@"(?:[^"\\]|\\.)*"\s*)+)', re.S)
LITERAL = re.compile(r'@"((?:[^"\\]|\\.)*)"')

# A line of a .strings file: "key" = "value";
ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;',
                   re.M)

# Words that only an Italian string would have. A heuristic, and it only
# decides which list a string is printed in — nothing is rewritten by it.
ITALIAN_WORDS = {
    "il", "lo", "la", "i", "gli", "le", "un", "una", "uno", "che", "non",
    "per", "con", "del", "della", "dei", "delle", "nel", "nella", "sul",
    "sulla", "come", "quando", "dove", "questo", "questa", "sono", "essere",
    "viene", "ancora", "solo", "anche", "già", "più", "meno", "senza",
    "dentro", "accanto", "prima", "dopo", "adesso", "niente", "nessun",
    "tutto", "cosa", "documento", "file", "pagina", "riga", "righe",
    "versione", "aggiornamento", "anteprima", "impostazioni", "titolo",
    "codice", "linguaggio", "parole", "cartella", "istruzioni", "plug-in",
    "di", "da", "tuo", "tua", "mio", "questi", "quelle", "sopra", "sotto",
}


def unescape(text):
    return (text.replace('\\"', '"').replace("\\n", "\n")
            .replace("\\t", "\t").replace("\\\\", "\\"))


def keys_in_sources():
    """Every key the code asks for, and where it asks for it."""
    where = defaultdict(list)
    for folder in SOURCES:
        for base, _, names in os.walk(folder):
            for name in names:
                if not name.endswith((".m", ".mm")):
                    continue
                path = os.path.join(base, name)
                with open(path, encoding="utf-8", errors="ignore") as handle:
                    text = handle.read()
                for match in CALL.finditer(text):
                    key = "".join(unescape(piece) for piece
                                  in LITERAL.findall(match.group(1)))
                    if not key:
                        continue
                    line = text.count("\n", 0, match.start()) + 1
                    where[key].append(
                        "%s:%d" % (os.path.relpath(path, ROOT), line))
    return where


def strings_files(language):
    folder = os.path.join(LOCALIZATIONS, language + ".lproj")
    if not os.path.isdir(folder):
        return []
    return [os.path.join(folder, name) for name in sorted(os.listdir(folder))
            if name.endswith(".strings")]


def entries(path):
    for encoding in ("utf-8", "utf-16"):
        try:
            with open(path, encoding=encoding) as handle:
                text = handle.read()
            break
        except (UnicodeError, UnicodeDecodeError):
            continue
    else:
        return {}
    return {unescape(k): unescape(v) for k, v in ENTRY.findall(text)}


def translated_keys(language):
    """Every key any .strings file of that language answers."""
    found = {}
    for path in strings_files(language):
        if os.path.basename(path) in ("InfoPlist.strings",):
            continue
        found.update(entries(path))
    return found


def classify_languages(keys):
    """Which language each key is written in, asked of NaturalLanguage.

    A word list gets single words wrong — "Aggiorna" and "Update" are both
    one word — and the answer decides which list a string is reported in, so
    it is worth asking something that knows. Falls back to the word list
    when the helper cannot be built.
    """
    keys = list(keys)
    helper = os.path.join(ROOT, "Tools", "language_of_strings.m")
    binary = os.path.join(tempfile.mkdtemp(), "language_of_strings")
    built = os.path.isfile(helper) and subprocess.call(
        ["clang", "-fobjc-arc", "-framework", "Foundation",
         "-framework", "NaturalLanguage", "-o", binary, helper],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0

    if built:
        lines = "\n".join(k.replace("\n", "\\n") for k in keys)
        answer = subprocess.run([binary], input=lines, capture_output=True,
                                text=True).stdout.split("\n")
        if len([a for a in answer if a]) == len(keys):
            decided = {}
            for i, key in enumerate(keys):
                # "und" means too short to tell — a word list is as good as
                # anything on three letters.
                decided[key] = (answer[i] if answer[i] in ("en", "it")
                                else ("it" if guess_italian(key) else "en"))
            return decided

    return {key: ("it" if guess_italian(key) else "en") for key in keys}


def guess_italian(key):
    """The word list, for what NaturalLanguage will not commit to."""
    words = re.findall(r"[\w']+", key.lower())
    return (any(word in ITALIAN_WORDS for word in words)
            or bool(re.search(r"[àèéìòù]", key.lower())))


def bundle_of(place):
    """Which bundle a string lives in, since each looks up its own.

    A plug-in's NSLocalizedString is answered by the plug-in's own bundle,
    so the application's Italian file cannot translate it however complete
    that file is.
    """
    if place.startswith("plugins" + os.sep) or place.startswith("plugins/"):
        return "plug-in " + place.replace(os.sep, "/").split("/")[1]
    if place.startswith("QuickLook"):
        return "Anteprima Finder"
    return None


def nib_objects(language):
    """The nib objects a language translates, per nib."""
    found = defaultdict(set)
    for path in strings_files(language):
        name = os.path.basename(path)
        if name == "InfoPlist.strings":
            continue
        for key in entries(path):
            if "." in key:
                found[name].add(key.split(".", 1)[0])
    return found


def base_nib_objects():
    """The objects in each base nib that carry a title or a label."""
    found = defaultdict(set)
    folder = os.path.join(LOCALIZATIONS, BASE + ".lproj")
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".xib"):
            continue
        with open(os.path.join(folder, name), encoding="utf-8",
                  errors="ignore") as handle:
            xml = handle.read()
        for match in re.finditer(
                r'<(menuItem|button|textField|buttonCell|textFieldCell|'
                r'tabViewItem|window|menu)\b[^>]*?\b(?:title|label|'
                r'placeholderString|stringValue)="([^"]{2,})"[^>]*?'
                r'\bid="([^"]+)"', xml):
            found[name.replace(".xib", ".strings")].add(match.group(3))
    return found


def main():
    wanted = sys.argv[1:]
    show_all = "--list" in wanted
    only = None
    if "--lang" in wanted:
        only = wanted[wanted.index("--lang") + 1]

    used = keys_in_sources()
    languages = sorted(
        name[:-len(".lproj")] for name in os.listdir(LOCALIZATIONS)
        if name.endswith(".lproj") and name[:-len(".lproj")] != BASE)

    outside = {k: bundle_of(v[0]) for k, v in used.items()}
    in_plugins = {k for k, b in outside.items() if b}
    used_by_app = {k: v for k, v in used.items() if k not in in_plugins}

    italian = translated_keys(ITALIAN)
    language_of = classify_languages(used)
    english_keys = {k for k in used_by_app if language_of.get(k) != "it"}
    italian_keys = {k for k in used_by_app if language_of.get(k) == "it"}

    print("\033[1mStringhe chieste dal codice\033[0m")
    print("  %d nell'applicazione: %d scritte in inglese, %d scritte in"
          " italiano" % (len(used_by_app), len(english_keys),
                         len(italian_keys)))
    by_bundle = defaultdict(list)
    for key in in_plugins:
        by_bundle[outside[key]].append(key)
    for bundle, keys in sorted(by_bundle.items()):
        print("  %d in %s: nessun file di lingua, si leggono come sono"
              " scritte" % (len(keys), bundle))

    missing_it = sorted(k for k in english_keys if k not in italian)
    untranslated_italian = sorted(k for k in italian_keys if k not in italian)
    print()
    print("\033[1mIn italiano\033[0m")
    print("  %d chiavi inglesi senza traduzione italiana%s"
          % (len(missing_it), " ✓" if not missing_it else ""))
    print("  %d chiavi già scritte in italiano: si leggono in italiano, e"
          " restano italiane in ogni altra lingua" % len(italian_keys))
    print("     (di cui %d senza una voce nel file italiano, cioè scritte"
          " solo nel codice)" % len(untranslated_italian))

    english = translated_keys(ENGLISH)
    italian_without_english = sorted(k for k in italian_keys
                                     if k not in english)
    print()
    print("\033[1mIn inglese\033[0m")
    print("  %d chiavi italiane senza traduzione inglese: un lettore inglese"
          " le vede in italiano%s"
          % (len(italian_without_english),
             " ✓" if not italian_without_english else ""))

    print()
    print("\033[1mNelle altre lingue\033[0m")
    rows = []
    for language in languages:
        if language in (BASE, ITALIAN):
            continue
        known = translated_keys(language)
        missing = [k for k in used_by_app if k not in known]
        rows.append((len(missing), language, len(known)))
    for missing, language, known in sorted(rows):
        print("  %-8s %4d tradotte, %4d mancanti" % (language, known, missing))

    print()
    print("\033[1mNei nib\033[0m")
    base = base_nib_objects()
    for nib, objects in sorted(base.items()):
        it_objects = nib_objects(ITALIAN).get(nib, set())
        missing = objects - it_objects
        if missing:
            print("  %-44s %d oggetti non tradotti" % (nib, len(missing)))
            if show_all:
                for one in sorted(missing):
                    print("      %s" % one)
    if not any(objects - nib_objects(ITALIAN).get(nib, set())
               for nib, objects in base.items()):
        print("  tutti tradotti ✓")

    if show_all or only:
        print()
        print("\033[1mChiavi inglesi senza italiano\033[0m")
        for key in missing_it:
            print("  %s\n      %s" % (key.replace("\n", "⏎"),
                                      used_by_app[key][0]))
        print()
        print("\033[1mChiavi scritte in italiano, senza inglese\033[0m")
        for key in italian_without_english:
            print("  %s\n      %s" % (key.replace("\n", "⏎")[:100],
                                      used_by_app[key][0]))

    if only:
        known = translated_keys(only)
        print()
        print("\033[1m%s: chiavi mancanti\033[0m" % only)
        for key in sorted(k for k in used_by_app if k not in known):
            print("  %s" % key.replace("\n", "⏎")[:100])

    # What a reader in the interface's own language would see untranslated:
    # an English key with no Italian, or an Italian key in an English
    # interface. Both are the same defect from opposite ends.
    return len(missing_it)


if __name__ == "__main__":
    sys.exit(main())
