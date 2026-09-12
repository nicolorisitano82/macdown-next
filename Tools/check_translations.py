#!/usr/bin/env python3
"""Tools/check_translations.py — what is translated, and what is not.

Reads every localized string the sources ask for and every .strings file in
the localizations, per bundle — the application has its own, and so does
each plug-in, because a plug-in's strings are answered by the plug-in's own
bundle and not by the application's.

It says four things:

  * which keys the code asks for and no language file answers — those show
    the reader the key itself;
  * which keys are written in Italian rather than English, which is why they
    *look* fine in Italian and appear as Italian in every other language;
  * which strings are not asked for through a localized call at all, and so
    cannot be translated in any language;
  * which nib objects the base nib has and a translation does not.

Which language a key is written in is asked of NaturalLanguage rather than
guessed from a word list, because a word list cannot tell "Aggiorna" from
"Update": Tools/language_of_strings.m is the twenty lines that ask.

Exit status is the number of strings that are missing a translation or
cannot be translated at all, so it is usable from a script.

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

BASE = "Base"
ENGLISH = "en"
ITALIAN = "it-IT"


class Bundle:
    """A bundle: sources that ask for strings, and the files that answer.

    The application's plug-ins are bundles of their own. NSLocalizedString
    asks the main bundle, so a plug-in uses its own macro and ships its own
    .lproj folders; keeping them apart here is what lets the count be true.
    """

    def __init__(self, name, sources, localizations, call):
        self.name = name
        self.sources = [os.path.join(ROOT, s) for s in sources]
        self.localizations = os.path.join(ROOT, localizations)
        # A backslash may sit between the call and its string, and between
        # two pieces of it: a localized string written inside a #define is
        # continued that way, and those were the ones this went past.
        self.call = re.compile(
            r'%s[\s\\]*\([\s\\]*((?:@"(?:[^"\\]|\\.)*"[\s\\]*)+)' % call,
            re.S)


BUNDLES = [
    Bundle("l'applicazione", ["MacDown/Code"],
           "MacDown/Localization", "NSLocalizedString"),
    Bundle("MacDownQuickLook.appex", ["QuickLook"],
           "QuickLook/Localization", "MDQLLocalizedString"),
    Bundle("Drawio.plugin", ["plugins/Drawio"],
           "plugins/Drawio/Localization", "MDLocalizedString"),
    Bundle("LoremIpsum.plugin", ["plugins/LoremIpsum"],
           "plugins/LoremIpsum/Localization", "LILocalizedString"),
    Bundle("DocumentImport.plugin", ["plugins/DocumentImport"],
           "plugins/DocumentImport/Localization", "DILocalized"),
]

LITERAL = re.compile(r'@"((?:[^"\\]|\\.)*)"', re.S)

# Any localized call at all, for finding the strings that are in none.
ANY_CALL = re.compile(
    r'\w*Localized\w*[\s\\]*\([\s\\]*(?:@"(?:[^"\\]|\\.)*"[\s\\]*)+', re.S)

# A line written to a diary rather than shown in the interface. The action
# log and the plug-in's log are diagnostics, in one language on purpose:
# they are read next to a stack trace, not in a menu. That language is
# English, and this checks it — an untranslatable string is bad enough
# without it being in a language the reader may not have.
LOG_CALL = re.compile(
    r'(?:MPNote|MDNote)\s*\(\s*(?:@"(?:[^"\\]|\\.)*"\s*)+'
    r'|(?:note|noteFormat):\s*(?:@"(?:[^"\\]|\\.)*"\s*)+', re.S)

# What a source says about itself: the literals that follow are content in
# the language they demonstrate, not interface text.
CONTENT_DIRECTIVE = "translation-check: content"

# A line of a .strings file: "key" = "value";
ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;',
                   re.M)

# Words that only an Italian string would have. Used for what
# NaturalLanguage will not commit to — three letters say little.
ITALIAN_WORDS = {
    "il", "lo", "la", "gli", "le", "un", "una", "uno", "che", "non",
    "per", "con", "del", "della", "dei", "delle", "nel", "nella", "sul",
    "sulla", "come", "quando", "dove", "questo", "questa", "sono", "essere",
    "viene", "ancora", "solo", "anche", "già", "più", "meno", "senza",
    "dentro", "accanto", "prima", "dopo", "adesso", "niente", "nessun",
    "tutto", "cosa", "documento", "pagina", "riga", "righe",
    "versione", "aggiornamento", "anteprima", "impostazioni", "titolo",
    "codice", "linguaggio", "parole", "cartella", "istruzioni",
    "di", "da", "tuo", "tua", "mio", "questi", "quelle", "sopra", "sotto",
}

# Words that are the same in both languages, or are nobody's language.
TECHNICAL = {
    "blockquote", "markdown", "tex", "mermaid", "graphviz", "smartypants",
    "html", "css", "epub", "pdf", "odt", "rtf", "json", "yaml", "xml",
    "lorem", "ipsum", "claude", "chatgpt", "github", "jekyll", "quicklook",
    "macdown", "next", "plug-in", "url",
}


def unescape(text):
    # A backslash at the end of a line is the preprocessor's, not the
    # string's: it joins the two lines and leaves nothing behind, so the key
    # the compiler ends up with — and the one a .strings file must carry —
    # has neither the backslash nor the newline.
    text = re.sub(r"\\\n", "", text)
    return (text.replace('\\"', '"').replace("\\n", "\n")
            .replace("\\t", "\t").replace("\\\\", "\\"))


def sources_of(bundle):
    for folder in bundle.sources:
        for base, _, names in os.walk(folder):
            for name in sorted(names):
                if name.endswith((".m", ".mm")):
                    yield os.path.join(base, name)


def keys_in_sources(bundle):
    """Every key that bundle's code asks for, and where it asks for it."""
    where = defaultdict(list)
    for path in sources_of(bundle):
        with open(path, encoding="utf-8", errors="ignore") as handle:
            text = handle.read()
        for match in bundle.call.finditer(text):
            key = "".join(unescape(piece) for piece
                          in LITERAL.findall(match.group(1)))
            if not key:
                continue
            line = text.count("\n", 0, match.start()) + 1
            where[key].append("%s:%d" % (os.path.relpath(path, ROOT), line))
    return where


def unreachable_strings(bundle):
    """Text that looks like Italian prose and is in no localized call.

    A string nobody asks for through a localized call cannot be translated
    in any language, however complete the files are — it is the one kind of
    gap a .strings file cannot close.
    """
    found = defaultdict(list)
    for path in sources_of(bundle):
        with open(path, encoding="utf-8", errors="ignore") as handle:
            text = handle.read()
        covered = [m.span() for m in ANY_CALL.finditer(text)]
        covered += [m.span() for m in LOG_CALL.finditer(text)]
        covered += content_regions(text)
        for match in LITERAL.finditer(text):
            if any(a <= match.start() < b for a, b in covered):
                continue
            value = unescape(match.group(1))
            if not looks_like_prose(value):
                continue
            line = text.count("\n", 0, match.start()) + 1
            found[value].append(
                "%s:%d" % (os.path.relpath(path, ROOT), line))
    return found


def content_regions(text):
    """The spans a source has marked as content rather than interface.

    Sample text has to be in the language it shows off — a plug-in that
    demonstrates Italian typography cannot demonstrate it in English — so a
    source says so, and this believes it as far as the end of the function.
    """
    spans = []
    for match in re.finditer(re.escape(CONTENT_DIRECTIVE), text):
        end = text.find("\n}", match.end())
        spans.append((match.start(), len(text) if end < 0 else end))
    return spans


def looks_like_prose(value):
    """Whether that literal is a sentence somebody reads, in Italian.

    Scripts, selectors and character sets are literals too, and the ones
    this file is full of contain Italian-looking fragments — "var i" has an
    "i" in it. Prose has words and no punctuation of code.
    """
    if re.search(r"[<>{}=;|]|\bvar\b|function|document\.|\.get", value):
        return False
    # Two words that are words, so that a set of characters to keep in a
    # file name is not read as a sentence.
    words = [word for word in re.findall(r"[a-z'àèéìòù]{2,}", value.lower())]
    if len(words) < 2:
        return False
    if re.search(r"[àèéìòù]", value.lower()):
        return True
    italian = sum(1 for word in words if word in ITALIAN_WORDS)
    return italian >= 2 or (italian == 1 and len(words) <= 4)


def log_lines(bundle):
    """The lines that bundle writes to a log, and where."""
    found = defaultdict(list)
    for path in sources_of(bundle):
        with open(path, encoding="utf-8", errors="ignore") as handle:
            text = handle.read()
        for match in LOG_CALL.finditer(text):
            line = "".join(unescape(piece) for piece
                           in LITERAL.findall(match.group(0)))
            if not line.strip() or not re.search(r"[A-Za-z]", line):
                continue
            where = text.count("\n", 0, match.start()) + 1
            found[line].append(
                "%s:%d" % (os.path.relpath(path, ROOT), where))
    return found


def strings_files(bundle, language):
    folder = os.path.join(bundle.localizations, language + ".lproj")
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


def translated_keys(bundle, language):
    """Every key any .strings file of that language answers."""
    found = {}
    for path in strings_files(bundle, language):
        if os.path.basename(path) == "InfoPlist.strings":
            continue
        found.update(entries(path))
    return found


def languages_of(bundle):
    if not os.path.isdir(bundle.localizations):
        return []
    return sorted(name[: -len(".lproj")]
                  for name in os.listdir(bundle.localizations)
                  if name.endswith(".lproj") and name != BASE + ".lproj")


def guess_italian(key):
    """The word list, for what NaturalLanguage will not commit to."""
    words = re.findall(r"[\w']+", key.lower())
    if words and all(word in TECHNICAL for word in words):
        return False
    return (any(word in ITALIAN_WORDS for word in words)
            or bool(re.search(r"[àèéìòù]", key.lower())))


def classify_languages(keys):
    """Which language each key is written in, asked of NaturalLanguage."""
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
                words = re.findall(r"[\w']+", key.lower())
                if words and all(word in TECHNICAL for word in words):
                    decided[key] = "en"
                elif answer[i] in ("en", "it"):
                    decided[key] = answer[i]
                else:
                    # "und" means too short to tell.
                    decided[key] = "it" if guess_italian(key) else "en"
            return decided

    return {key: ("it" if guess_italian(key) else "en") for key in keys}


def nib_objects(bundle, language):
    """The nib objects a language translates, per nib."""
    found = defaultdict(set)
    for path in strings_files(bundle, language):
        name = os.path.basename(path)
        if name == "InfoPlist.strings":
            continue
        for key in entries(path):
            if "." in key:
                found[name].add(key.split(".", 1)[0])
    return found


def base_nib_objects(bundle):
    """The objects in each base nib that carry a title or a label."""
    found = defaultdict(set)
    folder = os.path.join(bundle.localizations, BASE + ".lproj")
    if not os.path.isdir(folder):
        return found
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

    failures = 0
    for bundle in BUNDLES:
        used = keys_in_sources(bundle)
        italian = translated_keys(bundle, ITALIAN)
        english = translated_keys(bundle, ENGLISH)
        language_of = classify_languages(used)
        english_keys = sorted(k for k in used if language_of[k] != "it")
        italian_keys = sorted(k for k in used if language_of[k] == "it")
        missing_it = [k for k in english_keys if k not in italian]
        missing_en = [k for k in italian_keys if k not in english]
        stranded = unreachable_strings(bundle)
        logs = log_lines(bundle)
        log_language = classify_languages(logs) if logs else {}
        italian_logs = sorted(k for k in logs if log_language[k] == "it")

        print("\033[1m%s\033[0m" % bundle.name)
        print("  %d stringhe chieste: %d in inglese, %d in italiano"
              % (len(used), len(english_keys), len(italian_keys)))
        print("  %d chiavi inglesi senza italiano%s"
              % (len(missing_it), " ✓" if not missing_it else ""))
        print("  %d chiavi italiane senza inglese%s"
              % (len(missing_en), " ✓" if not missing_en else ""))
        print("  %d stringhe fuori da ogni chiamata, non traducibili%s"
              % (len(stranded), " ✓" if not stranded else ""))
        if logs:
            print("  %d righe di diario, di cui %d non in inglese%s"
                  % (len(logs), len(italian_logs),
                     " ✓" if not italian_logs else ""))
        failures += (len(missing_it) + len(missing_en) + len(stranded)
                     + len(italian_logs))

        base = base_nib_objects(bundle)
        if base:
            gaps = {nib: objects - nib_objects(bundle, ITALIAN).get(nib, set())
                    for nib, objects in base.items()}
            gaps = {nib: missing for nib, missing in gaps.items() if missing}
            if gaps:
                for nib, missing in sorted(gaps.items()):
                    print("  %-44s %d oggetti nei nib non tradotti"
                          % (nib, len(missing)))
                    if show_all:
                        for one in sorted(missing):
                            print("      %s" % one)
                failures += sum(len(m) for m in gaps.values())
            else:
                print("  nei nib: tutti tradotti ✓")

        others = [language for language in languages_of(bundle)
                  if language not in (ITALIAN, ENGLISH)]
        if others:
            rows = sorted((len([k for k in used if k not in
                                translated_keys(bundle, language)]),
                           language) for language in others)
            print("  altre lingue: %s" % ", ".join(
                "%s %d mancanti" % (language, missing)
                for missing, language in rows[:3]))
            print("                … fino a %s con %d mancanti"
                  % (rows[-1][1], rows[-1][0]))

        if show_all or only:
            for title, keys in (("Chiavi inglesi senza italiano", missing_it),
                                ("Chiavi italiane senza inglese", missing_en),
                                ("Fuori da ogni chiamata", sorted(stranded)),
                                ("Righe di diario non in inglese",
                                 italian_logs)):
                if not keys:
                    continue
                print("  \033[1m%s\033[0m" % title)
                for key in keys:
                    place = (used.get(key) or stranded.get(key)
                             or logs.get(key))[0]
                    print("    %s\n        %s"
                          % (key.replace("\n", "⏎")[:96], place))
        if only:
            known = translated_keys(bundle, only)
            missing = sorted(k for k in used if k not in known)
            print("  \033[1m%s: %d chiavi mancanti\033[0m"
                  % (only, len(missing)))
            for key in missing:
                print("    %s" % key.replace("\n", "⏎")[:96])
        print()

    return failures


if __name__ == "__main__":
    sys.exit(main())
