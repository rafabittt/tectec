#!/bin/bash
# Compila o TecTec e monta TecTec.app nesta pasta.
#
#   ./build.sh                → build local, assinatura ad-hoc (para desenvolver)
#   SIGN_ID="Developer ID Application" ./build.sh
#                             → assinatura de distribuição com Hardened Runtime (usado por tools/release.sh)
set -euo pipefail
cd "$(dirname "$0")"
source version.env   # VERSION e BUILD

swift build -c release --arch arm64 --arch x86_64 >/dev/null
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

APP="TecTec.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/TecTec" "$APP/Contents/MacOS/TecTec"
cp -R "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/"
cp -R Resources/Switches "$APP/Contents/Resources/Switches"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
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
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
  <key>CFBundleLocalizations</key><array><string>pt-BR</string></array>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>MIT · Sons de switches: kbsim (MIT) © Thomas Lai.</string>
  <key>SUFeedURL</key><string>https://raw.githubusercontent.com/rafabittt/tectec/main/appcast.xml</string>
  <key>SUPublicEDKey</key><string>U720P9Se8j8/B6uOB9bgcYPEDhVDnmdTXoo1Gou2D5Y=</string>
  <key>SUEnableAutomaticChecks</key><true/>
</dict>
</plist>
PLIST

FW="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -n "${SIGN_ID:-}" ]]; then
  # Distribuição: assina de dentro para fora, com Hardened Runtime e timestamp (exigidos pela notarização).
  OPTS=(--force --options runtime --timestamp --sign "$SIGN_ID")
  codesign "${OPTS[@]}" "$FW/Versions/B/XPCServices/Installer.xpc"
  codesign "${OPTS[@]}" --preserve-metadata=entitlements "$FW/Versions/B/XPCServices/Downloader.xpc"
  codesign "${OPTS[@]}" "$FW/Versions/B/Autoupdate"
  codesign "${OPTS[@]}" "$FW/Versions/B/Updater.app"
  codesign "${OPTS[@]}" "$FW"
  codesign "${OPTS[@]}" "$APP"
  codesign --verify --deep --strict "$APP"
else
  # Local: ad-hoc com requisito fixo pelo identificador, para a permissão de teclado sobreviver a rebuilds.
  codesign --force --deep --sign - "$FW" >/dev/null
  codesign --force --sign - -r="designated => identifier \"br.tectec.app\"" "$APP" >/dev/null
fi
echo "Pronto: $(pwd)/$APP ($VERSION, build $BUILD)"
