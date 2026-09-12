#!/bin/bash
#
# Builds DocumentImport.plugin and, with --install, puts it where MacDown
# Next looks for plug-ins.
#
# The plug-in **ships inside the application** — there is an Xcode target
# for it, and the build puts it in Contents/PlugIns — so nobody has to run
# this to get it. It is here for working on the plug-in without rebuilding
# the application, and for trying a copy of your own: of two with the same
# name the newer one wins, so the installed copy takes over until a newer
# build of the application overtakes it again.
#
# Two files: the plug-in itself, which is windows and files, and the
# conversion, which is neither — so that the conversion can be built on its
# own by tests/run.sh and asked about a hundred documents without a window
# ever opening.
set -e

cd "$(dirname "$0")"
NAME=DocumentImport
OUT="$NAME.plugin"
SDK=$(xcrun --show-sdk-path)

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp Info.plist "$OUT/Contents/Info.plist"
cp -R Localization/*.lproj "$OUT/Contents/Resources/"

clang -bundle -fobjc-arc \
    -isysroot "$SDK" \
    -mmacosx-version-min=26.0 \
    -framework Cocoa \
    -framework UniformTypeIdentifiers \
    -o "$OUT/Contents/MacOS/$NAME" \
    "$NAME.m" MDOfficeImport.m

echo "built $OUT"

if [ "$1" = "--install" ]; then
    DEST="$HOME/Library/Application Support/MacDown/PlugIns"
    mkdir -p "$DEST"
    rm -rf "$DEST/$OUT"
    cp -R "$OUT" "$DEST/"
    echo "installed in $DEST"
    echo "Restart MacDown Next: plug-ins are read once, at launch."
fi
