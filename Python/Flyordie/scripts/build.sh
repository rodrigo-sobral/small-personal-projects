#!/usr/bin/env bash
# Build a standalone FlyOrDie application (and a .dmg installer on macOS).
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="$PWD"
VERSION="$(sed -n 's/^version = "\(.*\)"$/\1/p' pyproject.toml | head -1)"

echo "==> Installing build dependencies"
uv sync --quiet --group dev

echo "==> Generating icons"
uv run python scripts/make_icons.py

echo "==> Running PyInstaller"
rm -rf build dist
uv run pyinstaller --noconfirm --clean flyordie.spec

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "==> Built $PROJECT/dist/FlyOrDie"
  exit 0
fi

APP="$PROJECT/dist/FlyOrDie.app"
DMG="$PROJECT/dist/FlyOrDie-$VERSION.dmg"
STAGE="$PROJECT/build/dmg"

echo "==> Signing app (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "==> Building installer disk image"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "FlyOrDie $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Built:"
echo "    $APP"
echo "    $DMG"
echo
echo "The build is ad-hoc signed, not notarised. On first launch, right-click"
echo "the app and choose Open, or run: xattr -dr com.apple.quarantine <app>"
