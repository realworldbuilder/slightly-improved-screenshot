#!/bin/bash
# Installs the latest Slightly Improved Screenshot release.
#   curl -fsSL https://realworldbuilder.github.io/slightly-improved-screenshot/install.sh | bash
set -euo pipefail

REPO="realworldbuilder/slightly-improved-screenshot"
APP="SlightlyImprovedScreenshot"
ZIP_URL="${SIS_ZIP_URL:-https://github.com/$REPO/releases/latest/download/$APP.zip}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Slightly Improved Screenshot only runs on macOS." >&2
  exit 1
fi
major="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$major" -lt 26 ]; then
  echo "macOS 26 or later is required (this Mac runs $(sw_vers -productVersion))." >&2
  exit 1
fi

# /Applications when writable, else the per-user folder. Override with SIS_INSTALL_DIR.
DEST="${SIS_INSTALL_DIR:-/Applications}"
if [ ! -w "$DEST" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading $APP…"
curl -fsSL "$ZIP_URL" -o "$tmp/$APP.zip"
ditto -x -k "$tmp/$APP.zip" "$tmp"
codesign --verify --deep --strict "$tmp/$APP.app"

if pgrep -x "$APP" >/dev/null; then
  echo "Quitting the running copy…"
  pkill -x "$APP" || true
  while pgrep -x "$APP" >/dev/null; do sleep 0.2; done
fi

echo "Installing to $DEST/$APP.app…"
rm -rf "$DEST/$APP.app"
ditto "$tmp/$APP.app" "$DEST/$APP.app"
xattr -dr com.apple.quarantine "$DEST/$APP.app" 2>/dev/null || true

if [ -z "${SIS_NO_LAUNCH:-}" ]; then
  open "$DEST/$APP.app"
fi

cat <<MSG

Installed. Look for the viewfinder icon in the menu bar, or press Shift-Command-2.
The first capture asks for Screen Recording access:
  System Settings > Privacy & Security > Screen & System Audio Recording
Grant it, then relaunch the app. Updating the app asks for it again.
MSG
