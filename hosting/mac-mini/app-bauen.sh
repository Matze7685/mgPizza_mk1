#!/bin/bash
# Baut die Menüleisten-App „Server-Zentrale“ und legt sie in den Ordner Programme.
# Braucht Xcode oder die Xcode-Befehlszeilenwerkzeuge.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/ServerZentrale" && pwd)"
APP="/Applications/Server-Zentrale.app"

echo "Baue die App …"
cd "$DIR"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/ServerZentrale"

echo "Lege $APP an …"
pkill -x ServerZentrale 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ServerZentrale"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Server-Zentrale</string>
    <key>CFBundleDisplayName</key><string>Server-Zentrale</string>
    <key>CFBundleIdentifier</key><string>de.mgpizza.serverzentrale</string>
    <key>CFBundleExecutable</key><string>ServerZentrale</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
open "$APP"
echo
echo "Fertig. Die App ist oben rechts in der Menüleiste (Server-Symbol)."
echo "Damit sie nach jedem Neustart startet: Systemeinstellungen → Allgemein → Anmeldeobjekte → + → Server-Zentrale."
