#!/usr/bin/env bash
# Claude Usage Monitor installer — downloads the latest release, replaces
# any previous install in /Applications, clears quarantine, launches.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/logan-jg/claude-usage-monitor/main/install.sh | bash
set -euo pipefail

APP_NAME="ClaudeUsageMonitor"
APP_PATH="/Applications/${APP_NAME}.app"
ZIP_URL="https://github.com/logan-jg/claude-usage-monitor/releases/latest/download/${APP_NAME}.zip"
TMP_DIR="$(mktemp -d)"
ZIP_PATH="${TMP_DIR}/${APP_NAME}.zip"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "📥  Downloading the latest ${APP_NAME}..."
curl -fsSL "$ZIP_URL" -o "$ZIP_PATH"

echo "🛑  Stopping any running instance..."
pkill -f "${APP_NAME}.app/Contents/MacOS" 2>/dev/null || true
sleep 1

echo "📦  Unpacking..."
/usr/bin/ditto -xk "$ZIP_PATH" "$TMP_DIR"

if [ ! -d "${TMP_DIR}/${APP_NAME}.app" ]; then
  echo "❌  Zip didn't contain ${APP_NAME}.app — aborting."
  exit 1
fi

echo "🗑   Replacing ${APP_PATH}..."
rm -rf "$APP_PATH"
mv "${TMP_DIR}/${APP_NAME}.app" "$APP_PATH"

echo "🔓  Clearing quarantine flag..."
xattr -dr com.apple.quarantine "$APP_PATH" || true

echo "🚀  Launching..."
open "$APP_PATH"

echo
echo "✅  Done. Look for the gauge icon in your menu bar (upper right)."
echo "    Future updates will install themselves via Sparkle — no need to rerun this."
