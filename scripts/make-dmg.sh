#!/bin/sh
# Packs Macaffeine.app into a drag-to-install disk image with a custom window.
#
#   scripts/make-dmg.sh <path/to/Macaffeine.app> <output.dmg>
#
# Finder lays out the window, so this needs a logged-in session (and Automation access to Finder).

set -eu
cd "$(dirname "$0")/.."

APP=${1:?usage: make-dmg.sh <Macaffeine.app> <output.dmg>}
OUT=${2:?usage: make-dmg.sh <Macaffeine.app> <output.dmg>}
VOLUME=Macaffeine

WORK=$(mktemp -d)
trap 'hdiutil detach "$WORK/mount" -quiet 2>/dev/null || true; rm -rf "$WORK"' EXIT

swift scripts/dmg/background.swift 1 "$WORK/background.png"
swift scripts/dmg/background.swift 2 "$WORK/background@2x.png"

mkdir -p "$WORK/stage/.background"
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" -out "$WORK/stage/.background/background.tiff" 2>/dev/null
ditto "$APP" "$WORK/stage/Macaffeine.app"
ln -s /Applications "$WORK/stage/Applications"
cp "$APP/Contents/Resources/AppIcon.icns" "$WORK/stage/.VolumeIcon.icns"

hdiutil create -quiet -srcfolder "$WORK/stage" -volname "$VOLUME" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg"
hdiutil attach -quiet -readwrite -noverify -noautoopen -mountpoint "$WORK/mount" "$WORK/rw.dmg"

# custom volume icon
if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$WORK/mount"
fi

# icons sit on the spotlights drawn in background.swift
osascript <<EOF
tell application "Finder"
    set dmg to POSIX file "$WORK/mount" as alias
    open dmg
    set win to container window of dmg
    set current view of win to icon view
    set toolbar visible of win to false
    set statusbar visible of win to false
    set bounds of win to {200, 120, 840, 548}
    set options to icon view options of win
    set arrangement of options to not arranged
    set icon size of options to 112
    set text size of options to 13
    set background picture of options to file ".background:background.tiff" of dmg
    set position of item "Macaffeine.app" of win to {170, 200}
    set position of item "Applications" of win to {470, 200}
    close win
    -- Finder reopens with its default size and saves that on close, so set it again
    open dmg
    set bounds of container window of dmg to {200, 120, 840, 548}
    delay 2
    close container window of dmg
    delay 2
end tell
EOF

rm -rf "$WORK/mount/.fseventsd"
sync
hdiutil detach -quiet "$WORK/mount"
rm -f "$OUT"
hdiutil convert -quiet "$WORK/rw.dmg" -format ULFO -o "$OUT"
echo "$OUT"
