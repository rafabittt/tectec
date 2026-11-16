#!/bin/bash
# Compila o TecTec e monta TecTec.app nesta pasta.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64 2>/dev/null || swift build -c release
BIN="$(swift build -c release --show-bin-path 2>/dev/null)/TecTec"
[ -f "$BIN" ] || BIN=".build/apple/Products/Release/TecTec"

APP="TecTec.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TecTec"
cp -R Resources/Switches "$APP/Contents/Resources/Switches"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>TecTec</string>
  <key>CFBundleDisplayName</key><string>TecTec</string>
  <key>CFBundleIdentifier</key><string>br.tectec.app</string>
  <key>CFBundleExecutable</key><string>TecTec</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>Sons de switches: kbsim (MIT) © Thomas Lai.</string>
</dict>
</plist>
PLIST

codesign --force --sign - -r="designated => identifier \"br.tectec.app\"" "$APP" >/dev/null
echo "Pronto: $(pwd)/$APP"
