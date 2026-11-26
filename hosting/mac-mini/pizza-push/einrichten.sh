#!/bin/bash
# Richtet Pizza-Push auf dem Mac mini ein: ein kleines Programm im Hintergrund, das dir eine Push-Nachricht aufs iPhone
# schickt, wenn ein Gast bestellt, seine Bestellung ändert oder löscht. Startet automatisch, sobald du angemeldet bist.
#
# Aufruf (die beiden Dateien aus der Anleitung, Schritt 1 und 2):
#   bash hosting/mac-mini/pizza-push/einrichten.sh ~/Downloads/<projekt>-firebase-adminsdk-….json ~/Downloads/AuthKey_ABCD123456.p8
# Nach einem Update einfach ohne Dateien erneut starten:
#   bash hosting/mac-mini/pizza-push/einrichten.sh
# Ausschalten:
#   bash hosting/mac-mini/pizza-push/einrichten.sh --aus
set -euo pipefail

LABEL="de.mgpizza.push"
AGENTS="$HOME/Library/LaunchAgents"
LOGS="$HOME/Library/Logs/mgpizza"
DIR="$HOME/.mgpizza/push"
TEAM_ID="WVD937X98R"                          # Apple-Team der App (steht im Xcode-Projekt)
BUNDLE_ID="com.einfachschwimmen.mgPizza-mk1"  # Bundle-ID der App
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31mFehler: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || fail "Dieses Skript ist nur für macOS gedacht."

if [ "${1:-}" = "--aus" ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$AGENTS/$LABEL.plist"
  say "Pizza-Push ist aus. (Schlüssel liegen weiter in $DIR, zum Löschen: rm -r $DIR)"
  exit 0
fi

PYTHON=/usr/bin/python3
"$PYTHON" -c 'import sys' 2>/dev/null || fail "python3 fehlt. Einmal im Terminal 'xcode-select --install' ausführen und danach dieses Skript erneut starten."

mkdir -p "$DIR" "$AGENTS" "$LOGS"
chmod 700 "$DIR"

say "1/4  Schlüssel übernehmen …"
SA="${1:-}"; P8="${2:-}"
if [ -n "$SA" ]; then
  [ -f "$SA" ] || fail "Datei nicht gefunden: $SA"
  grep -q '"private_key"' "$SA" || fail "$SA ist kein Firebase-Dienstkonto-Schlüssel (Anleitung Schritt 1)."
  cp "$SA" "$DIR/service-account.json"
  rm -f "$DIR/google-key.pem"   # wird beim Start neu aus dem Dienstkonto erzeugt
fi
if [ -n "$P8" ]; then
  [ -f "$P8" ] || fail "Datei nicht gefunden: $P8"
  KEY_ID="$(basename "$P8" | sed -n 's/^AuthKey_\([A-Z0-9]*\)\.p8$/\1/p')"
  [ -n "$KEY_ID" ] || fail "Der Apple-Schlüssel muss AuthKey_<SCHLÜSSEL-ID>.p8 heißen (so lädt Apple ihn herunter)."
  cp "$P8" "$DIR/apns.p8"
  printf '{"serviceAccountFile": "service-account.json", "apnsKeyFile": "apns.p8", "apnsKeyId": "%s", "teamId": "%s", "bundleId": "%s"}\n' \
    "$KEY_ID" "$TEAM_ID" "$BUNDLE_ID" > "$DIR/config.json"
fi
[ -f "$DIR/service-account.json" ] && [ -f "$DIR/apns.p8" ] && [ -f "$DIR/config.json" ] \
  || fail "Beim ersten Mal bitte beide Dateien angeben (siehe Kopf dieses Skripts)."
chmod 600 "$DIR"/*
echo "  Schlüssel liegen in $DIR"

say "2/4  Programm kopieren …"
cp "$SCRIPT_DIR/pizza_push.py" "$DIR/pizza_push.py"

say "3/4  Test-Nachricht schicken …"
echo "  (Vorher in der App unter Menü → Guest link „Push for guest orders“ einschalten.)"
"$PYTHON" "$DIR/pizza_push.py" --test || fail "Test fehlgeschlagen, siehe Meldung oben."

say "4/4  Im Hintergrund starten …"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
sleep 1
cat > "$AGENTS/$LABEL.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON</string>
        <string>$DIR/pizza_push.py</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>30</integer>
    <key>StandardOutPath</key>
    <string>$LOGS/push.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS/push.log</string>
</dict>
</plist>
PLIST
plutil -lint "$AGENTS/$LABEL.plist" >/dev/null
launchctl bootstrap "gui/$(id -u)" "$AGENTS/$LABEL.plist"
sleep 3
tail -n 3 "$LOGS/push.log" || true

say "Fertig. Pizza-Push läuft und startet nach jedem Neustart von selbst."
echo "Protokoll ansehen:  tail -f $LOGS/push.log"
