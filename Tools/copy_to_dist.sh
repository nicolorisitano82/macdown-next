#!/bin/bash
#
# Puts the built application, and the plug-ins built beside it, into
# dist/<configuration>, with the version stamped on the copy.
#
#   Tools/copy_to_dist.sh Release ["/path/to/Build/Products/Release"]
#
# Called twice, on purpose. Xcode calls it from a build phase, which is
# convenient while working but runs *in the middle* of the target: at that
# moment the application's Info.plist has not been written yet and it has
# not been signed. On an incremental build the previous copy hides that; on
# a clean one it does not, and what landed in dist/ was an application with
# a one-key Info.plist and no signature — which is how this script came to
# exist. So it refuses to copy something that is not finished, and whoever
# makes a release calls it again afterwards, when the application is.

set -o errexit
set -o nounset
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-Release}"
PRODUCTS="${2:-}"

if [ -z "$PRODUCTS" ]; then
    PRODUCTS=$(cd "$ROOT" && xcodebuild -workspace MacDown.xcworkspace \
        -scheme MacDown -configuration "$CONFIGURATION" \
        -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/ BUILT_PRODUCTS_DIR =/ {print $2; exit}')
fi
[ -n "$PRODUCTS" ] || { echo "non so dove sono i prodotti" >&2; exit 2; }

APP=$(ls -d "$PRODUCTS"/*.app 2>/dev/null | head -1)
[ -n "$APP" ] || { echo "nessuna app in $PRODUCTS" >&2; exit 3; }
NAME="$(basename "$APP")"

# The Info.plist is written at the end of the target, after the script
# phases: no plist means the application is still being put together, and
# copying it now would leave a broken one in dist/.
EXECUTABLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" \
    "$APP/Contents/Info.plist" 2>/dev/null || true)
if [ -z "$EXECUTABLE" ] || [ ! -x "$APP/Contents/MacOS/$EXECUTABLE" ]; then
    echo "note: $NAME non è ancora finita — dist/$CONFIGURATION lasciata com'è"
    exit 0
fi

DEST="$ROOT/dist/$CONFIGURATION"
mkdir -p "$DEST"
rm -rf "$DEST/$NAME"
cp -R "$APP" "$DEST/"

# The plug-ins built alongside go too: one is installed through the plug-in
# manager, which asks for a .plugin to point at.
for PLUGIN in "$PRODUCTS"/*.plugin; do
    [ -e "$PLUGIN" ] || continue
    rm -rf "$DEST/$(basename "$PLUGIN")"
    cp -R "$PLUGIN" "$DEST/"
done

# The version goes on the copy, by an explicit path: stamped inside the
# build it does not survive, because the build system writes the Info.plist
# again after the script phases have run.
PLIST="$DEST/$NAME/Contents/Info.plist"
SHORT=$("$ROOT/Tools/short_version.sh")
BUNDLE=$(cd "$ROOT" && git rev-list --count HEAD)
BUILD=$(cd "$ROOT" && git describe --tags --always --dirty=+)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleBuildVersion string $BUILD" "$PLIST" \
    2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleBuildVersion $BUILD" "$PLIST"

echo "note: dist copy stamped $SHORT ($BUNDLE)"
bash "$ROOT/Tools/stamp_extension.sh" "$DEST/$NAME"
