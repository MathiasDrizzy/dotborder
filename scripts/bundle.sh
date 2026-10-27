#!/usr/bin/env bash
# Builds dotborder in release and wraps it in dotborder.app (LSUIElement keeps it out of the Dock). Signed with the local
# certificate when there is one (scripts/signing-identity.sh), ad hoc otherwise. The app needs no macOS permission.
#   scripts/bundle.sh            -> .build/dotborder.app (git-ignored); the build itself goes to ~/.cache/dotborder-build
#   scripts/bundle.sh <folder>   -> <folder>/dotborder.app
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/.build}"
APP="$OUT/dotborder.app"
BUILD_SECONDS=600 # a build that hangs is given up

# The build goes under HOME, not into the repo: an installer run must not need to write to the checkout.
SCRATCH="${HOME}/.cache/dotborder-build"
mkdir -p "$SCRATCH"
FLAGS=(-c release --package-path "$ROOT" --scratch-path "$SCRATCH")
/usr/bin/perl -e 'alarm shift; exec @ARGV' "$BUILD_SECONDS" swift build "${FLAGS[@]}" --product dotborder
BIN="$(swift build "${FLAGS[@]}" --show-bin-path)/dotborder"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/dotborder"
/usr/bin/plutil -lint "$APP/Contents/Info.plist" >/dev/null
# Signed with the local certificate, every build keeps the permissions macOS granted (see signing-identity.sh); where it
# cannot be made (no login keychain), ad hoc, and the permissions are asked again after each build.
IDENTITY="$("$ROOT/scripts/signing-identity.sh" 2>/dev/null)" || IDENTITY="-"
if ! codesign -s "$IDENTITY" --force --identifier dev.dotfiles.dotborder "$APP" 2>/dev/null; then
  echo "dotborder: signed ad hoc: macOS will ask for its permissions again" >&2
  codesign -s - --force --identifier dev.dotfiles.dotborder "$APP"
fi
codesign --verify "$APP"
echo "$APP"
