#!/bin/bash
#
# Builds LoremIpsum.plugin and, with --install, puts it where MacDown Next looks.
#
# A .plugin is a bundle: an Info.plist naming a principal class, and a binary
# built with -bundle. No Xcode target is needed, which is the point — a
# plug-in is meant to be something you can write on your own without adding
# anything to MacDown Next's project.
set -e

cd "$(dirname "$0")"
NAME=LoremIpsum
OUT="$NAME.plugin"
SDK=$(xcrun --show-sdk-path)

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS"
cp Info.plist "$OUT/Contents/Info.plist"

# The plug-in's own languages. A plug-in that left its strings to the
# application would not be installable on its own.
mkdir -p "$OUT/Contents/Resources"
cp -R Localization/*.lproj "$OUT/Contents/Resources/"

clang -bundle -fobjc-arc \
    -isysroot "$SDK" \
    -mmacosx-version-min=26.0 \
    -framework Cocoa \
    -o "$OUT/Contents/MacOS/$NAME" \
    "$NAME.m"

echo "built $OUT"

if [ "$1" = "--install" ]; then
    DEST="$HOME/Library/Application Support/MacDown/PlugIns"
    mkdir -p "$DEST"
    rm -rf "$DEST/$OUT"
    cp -R "$OUT" "$DEST/"
    echo "installed in $DEST"
    echo "Restart MacDown Next: plug-ins are read once, at launch."
fi
