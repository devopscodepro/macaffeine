#!/bin/sh
# Builds a signed, notarized Macaffeine.app and packs it as a disk image and a zip for a GitHub release.
#
#   scripts/release.sh            sign with Developer ID and notarize
#   scripts/release.sh --dry-run  ad-hoc signed build, no notarization (checks the pipeline)
#
# Needs a "Developer ID Application" identity in the keychain and a notarytool profile:
#   xcrun notarytool store-credentials macaffeine-notary --apple-id <id> --team-id <team>

set -eu
cd "$(dirname "$0")/.."

IDENTITY=${MACAFFEINE_SIGN_IDENTITY:-Developer ID Application}
PROFILE=${MACAFFEINE_NOTARY_PROFILE:-macaffeine-notary}
DRY_RUN=0
[ "${1:-}" = --dry-run ] && DRY_RUN=1

step() {
    printf '\n==> %s\n' "$*"
}

die() {
    echo "release: $*" >&2
    exit 1
}

# submit, then wait separately so a dropped connection doesn't lose the result
notarize() {
    file=$1
    log=$2
    id=$(xcrun notarytool submit "$file" --keychain-profile "$PROFILE" --output-format json | sed -n 's/.*"id" *: *"\([^"]*\)".*/\1/p')
    [ -n "$id" ] || die "notarytool didn't return a submission id for $file"
    echo "submitted $file as $id"
    for attempt in 1 2 3 4 5; do
        xcrun notarytool wait "$id" --keychain-profile "$PROFILE" --timeout 30m && break
        echo "waiting for $id failed (attempt $attempt), retrying"
        sleep 20
    done
    xcrun notarytool info "$id" --keychain-profile "$PROFILE" | tee "$log"
    xcrun notarytool log "$id" --keychain-profile "$PROFILE" "${log%.log}-details.json" >/dev/null 2>&1 || true
    grep -q "status: Accepted" "$log" || die "notarization of $file was not accepted, see $log"
}

VERSION=$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' Macaffeine.xcodeproj/project.pbxproj | sort -u)
[ "$(echo "$VERSION" | wc -l | tr -d ' ')" = 1 ] || die "MARKETING_VERSION differs between configurations"
BUILD=$(git rev-list --count HEAD)
OUT=dist/$VERSION
APP=$OUT/Macaffeine.app
ZIP=$OUT/Macaffeine-$VERSION.zip
DMG=$OUT/Macaffeine-$VERSION.dmg

if [ $DRY_RUN = 0 ]; then
    [ -z "$(git status --porcelain)" ] || die "working tree is not clean"
    security find-identity -v -p codesigning | grep -q "$IDENTITY" || die "no \"$IDENTITY\" identity in the keychain"
fi

step "Building $VERSION ($BUILD)"
rm -rf "$OUT"
mkdir -p "$OUT"
xcodebuild -project Macaffeine.xcodeproj -scheme Macaffeine -configuration Release \
    -derivedDataPath build/Release \
    CURRENT_PROJECT_VERSION="$BUILD" \
    clean build >"$OUT/build.log" 2>&1 || die "build failed, see $OUT/build.log"
ditto build/Release/Build/Products/Release/Macaffeine.app "$APP"

step "Signing"
codesign -d --entitlements - --xml "$APP" >"$OUT/entitlements.plist" 2>/dev/null
# Xcode adds get-task-allow for local signing, notarization rejects it
/usr/libexec/PlistBuddy -c "Delete :com.apple.security.get-task-allow" "$OUT/entitlements.plist" 2>/dev/null || true
grep -q com.apple.security.app-sandbox "$OUT/entitlements.plist" || die "sandbox entitlement is missing"
if [ $DRY_RUN = 1 ]; then
    codesign --force --options runtime --entitlements "$OUT/entitlements.plist" --sign - "$APP"
else
    codesign --force --options runtime --timestamp --entitlements "$OUT/entitlements.plist" --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict --deep "$APP"

if [ $DRY_RUN = 0 ]; then
    step "Notarizing"
    ditto -c -k --keepParent "$APP" "$OUT/notarize.zip"
    notarize "$OUT/notarize.zip" "$OUT/notarize.log"
    rm "$OUT/notarize.zip"
    xcrun stapler staple "$APP"
    spctl --assess --type execute --verbose "$APP"
fi

step "Packing"
ditto -c -k --keepParent "$APP" "$ZIP"

# Finder lays out the disk image window, which CI machines can't do
if [ -n "${CI:-}" ]; then
    echo "CI: skipping the disk image"
else
    scripts/make-dmg.sh "$APP" "$DMG" >/dev/null
    if [ $DRY_RUN = 0 ]; then
        codesign --force --timestamp --sign "$IDENTITY" "$DMG"
        notarize "$DMG" "$OUT/notarize-dmg.log"
        xcrun stapler staple "$DMG"
    fi
fi

(cd "$OUT" && shasum -a 256 Macaffeine-"$VERSION".* >SHA256SUMS)

# release notes are the changelog section for this version
awk -v version="$VERSION" '
    $0 ~ "^## \\[" version "\\]" { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
' CHANGELOG.md | sed '/./,$!d' >"$OUT/notes.md"
[ -s "$OUT/notes.md" ] || echo "release: no \"## [$VERSION]\" section in CHANGELOG.md, notes.md is empty" >&2

step "Done"
ls -lh "$OUT"
cat "$OUT/SHA256SUMS"
