#!/bin/bash
#
# Builds the disk image, with the background that shows where to drag.
#
#   Tools/make_dmg.sh "dist/Release/MacDown Next.app" 0.17.0 [background.png]
#
# The background is given at 2x and split into a two-representation TIFF, so
# the picture is sharp on a Retina screen and correct on one that is not.
# Finder is asked to place the icons over the two drop zones drawn in it.

set -o errexit
set -o nounset
set -o pipefail

APP="${1:?percorso del bundle .app}"
VERSION="${2:?versione}"
# The picture that shows where to drag is the one in Tools/ unless another
# is named. It used to be the third argument and nothing else: two releases
# went out with a blank disk image because whoever built them — me — simply
# forgot to pass it.
BACKGROUND="${3:-$(cd "$(dirname "$0")" && pwd)/dmg-background.png}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Taken from the bundle rather than written here, so a rename of the
# product carries the disk image with it.
NAME="$(basename "$APP" .app)"
VOLUME="$NAME $VERSION"
# Without the space: a file whose name has one in it is quoting trouble for
# everybody who downloads it.
OUT="$ROOT/dist/${NAME// /}-$VERSION.dmg"

# Points, and the positions the drop zones sit at in the picture.
WIDTH=793
HEIGHT=496
APP_X=200
APP_Y=248
LINK_X=592
LINK_Y=248

STAGE="$(mktemp -d)"
# The image is built beside the staging folder, never inside it: hdiutil
# copies everything under the source, and a growing disk image that contains
# itself fills the disk before it fills the image.
WORK="$(mktemp -d)"
trap 'rm -rf "$STAGE" "$WORK"' EXIT

echo "note: staging $NAME.app"
cp -R "$APP" "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"

if [ ! -f "$BACKGROUND" ]; then
    # Said out loud rather than skipped quietly: a disk image with no
    # background is one nobody notices until it is downloaded.
    echo "attenzione: sfondo non trovato — $BACKGROUND" >&2
    echo "            l'immagine verrà senza. Se è voluto, passa /dev/null" >&2
fi

if [ -f "$BACKGROUND" ]; then
    mkdir -p "$STAGE/.background"
    sips -s format png -z "$((HEIGHT))" "$((WIDTH))" "$BACKGROUND" \
        --out "$STAGE/.background/background.png" > /dev/null
    sips -s format png -z "$((HEIGHT * 2))" "$((WIDTH * 2))" "$BACKGROUND" \
        --out "$STAGE/.background/background@2x.png" > /dev/null
    tiffutil -cathidpicheck \
        "$STAGE/.background/background.png" \
        "$STAGE/.background/background@2x.png" \
        -out "$STAGE/.background/background.tiff" > /dev/null
    rm -f "$STAGE/.background/background.png" \
          "$STAGE/.background/background@2x.png"
    echo "note: background prepared"
fi

RW="$WORK/rw.dmg"
MOUNT="/Volumes/$VOLUME"

# Room to spare: a read-write image cannot grow, and Finder writes its own
# view settings into it.
SIZE=$(( $(du -sm "$STAGE" | cut -f1) + 40 ))
hdiutil create -srcfolder "$STAGE" -volname "$VOLUME" -fs HFS+ \
    -format UDRW -size "${SIZE}m" -ov "$RW" > /dev/null

hdiutil attach "$RW" -readwrite -noverify -noautoopen > /dev/null
sleep 2

if [ -d "$MOUNT/.background" ]; then
osascript <<EOF > /dev/null || echo "warning: Finder would not lay the window out"
tell application "Finder"
  tell disk "$VOLUME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, ${WIDTH} + 200, ${HEIGHT} + 120}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    set background picture of theViewOptions to file ".background:background.tiff"
    set position of item "$NAME.app" of container window to {$APP_X, $APP_Y}
    set position of item "Applications" of container window to {$LINK_X, $LINK_Y}
    update without registering applications
    delay 2
    close
  end tell
end tell
EOF
fi

sync
# Finder holds the volume for a moment after closing its window, and a
# convert that starts too early fails with a resource that is busy.
for attempt in 1 2 3 4 5; do
    if hdiutil detach "$MOUNT" > /dev/null 2>&1; then
        break
    fi
    sleep 2
    if [ "$attempt" = "5" ]; then
        hdiutil detach "$MOUNT" -force > /dev/null 2>&1 || true
    fi
done
while [ -d "$MOUNT" ]; do sleep 1; done
sleep 1

rm -f "$OUT"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" > /dev/null
echo "note: wrote $OUT"
