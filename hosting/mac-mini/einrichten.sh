#!/bin/bash
# Richtet die Gästeseite auf dem Mac mini ein:
#   1. kleiner Webserver (Caddy), der den Ordner docs/ auf http://127.0.0.1:8080 anbietet
#   2. Cloudflare Tunnel, der die Seite per https im Internet erreichbar macht
# Beide starten automatisch, sobald du am Mac angemeldet bist (launchd).
#
# Aufruf:
#   bash hosting/mac-mini/einrichten.sh                          -> Schnell-Tunnel (kostenlos, Adresse ändert sich nach Neustart)
#   bash hosting/mac-mini/einrichten.sh pizza pizza.meinedomain.de -> fester Tunnel mit eigener Domain (siehe ANLEITUNG.md, Weg B)
set -euo pipefail

PORT=8080
LABEL_WEB="de.mgpizza.webserver"
LABEL_TUN="de.mgpizza.tunnel"
AGENTS="$HOME/Library/LaunchAgents"
LOGS="$HOME/Library/Logs/mgpizza"
STATE="$HOME/.mgpizza"

TUNNEL_NAME="${1:-}"
TUNNEL_HOST="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
SITE="$REPO/docs"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31mFehler: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || fail "Dieses Skript ist nur für macOS gedacht."
[ -f "$SITE/index.html" ] || fail "Keine Gästeseite gefunden unter $SITE/index.html"

if [ -n "$TUNNEL_NAME" ] && [ -z "$TUNNEL_HOST" ]; then
  fail "Für den festen Tunnel bitte Name UND Adresse angeben, z. B.: bash $0 pizza pizza.meinedomain.de"
fi

# macOS sperrt Hintergrunddiensten den Zugriff auf Schreibtisch, Dokumente und Downloads.
case "$REPO" in
  "$HOME/Desktop"*|"$HOME/Documents"*|"$HOME/Downloads"*|"$HOME/Library/Mobile Documents"*)
    fail "Der Projektordner liegt in Schreibtisch/Dokumente/Downloads/iCloud ($REPO).
Dort darf der Webserver im Hintergrund nicht lesen. Bitte das Projekt direkt in deinen
Benutzerordner klonen (z. B. ~/mgPizza_mk1) und das Skript von dort starten." ;;
esac

# Homebrew finden
if ! command -v brew >/dev/null 2>&1; then
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$b" ] && eval "$("$b" shellenv)" && break
  done
fi
command -v brew >/dev/null 2>&1 || fail "Homebrew ist nicht installiert. Bitte zuerst Schritt 2 der Anleitung ausführen."
BREW_BIN="$(brew --prefix)/bin"

say "1/4  Programme installieren (Caddy und cloudflared) …"
for pkg in caddy cloudflared; do
  if [ -x "$BREW_BIN/$pkg" ]; then echo "  $pkg ist schon da."; else brew install "$pkg"; fi
done
CADDY="$BREW_BIN/caddy"
CLOUDFLARED="$BREW_BIN/cloudflared"

mkdir -p "$AGENTS" "$LOGS" "$STATE"

# Alte Dienste stoppen (falls das Skript schon einmal lief)
for label in "$LABEL_WEB" "$LABEL_TUN"; do
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
done
sleep 2

write_plist() { # $1=label  $2=logname  $3...=Befehl
  local label="$1" log="$2"; shift 2
  local args=""
  for a in "$@"; do args="$args        <string>$a</string>
"; done
  cat > "$AGENTS/$label.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
$args    </array>
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
    <integer>10</integer>
    <key>StandardOutPath</key>
    <string>$LOGS/$log.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS/$log.log</string>
</dict>
</plist>
PLIST
  plutil -lint "$AGENTS/$label.plist" >/dev/null
}

say "2/4  Webserver einrichten (Ordner: $SITE) …"
write_plist "$LABEL_WEB" webserver "$CADDY" file-server --root "$SITE" --listen "127.0.0.1:$PORT"
: > "$LOGS/webserver.log"
launchctl bootstrap "gui/$(id -u)" "$AGENTS/$LABEL_WEB.plist"

ok=""
for _ in $(seq 1 15); do
  if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/"; then ok=1; break; fi
  sleep 1
done
[ -n "$ok" ] || fail "Der Webserver antwortet nicht. Protokoll: $LOGS/webserver.log"
echo "  Webserver läuft: http://127.0.0.1:$PORT/"

say "3/4  Cloudflare Tunnel einrichten …"
if [ -z "$TUNNEL_NAME" ]; then
  # Schnell-Tunnel (trycloudflare.com), braucht kein Konto
  rm -f "$STATE/fester-tunnel"
  write_plist "$LABEL_TUN" tunnel "$CLOUDFLARED" tunnel --no-autoupdate --url "http://127.0.0.1:$PORT"
else
  # Fester Tunnel mit eigener Domain
  [ -f "$HOME/.cloudflared/cert.pem" ] || fail "Noch nicht bei Cloudflare angemeldet. Bitte zuerst ausführen: cloudflared tunnel login"
  if ! "$CLOUDFLARED" tunnel list 2>/dev/null | awk 'NR>1{print $2}' | grep -qx "$TUNNEL_NAME"; then
    "$CLOUDFLARED" tunnel create "$TUNNEL_NAME"
  fi
  TUNNEL_ID="$("$CLOUDFLARED" tunnel list 2>/dev/null | awk -v n="$TUNNEL_NAME" '$2==n{print $1}' | head -1)"
  [ -n "$TUNNEL_ID" ] || fail "Tunnel '$TUNNEL_NAME' nicht gefunden."
  "$CLOUDFLARED" tunnel route dns "$TUNNEL_NAME" "$TUNNEL_HOST" \
    || echo "  Hinweis: DNS-Eintrag konnte nicht angelegt werden (gibt es ihn schon?). Siehe ANLEITUNG.md, Fehlerhilfe."
  CONFIG="$STATE/tunnel-config.yml"
  cat > "$CONFIG" <<YML
tunnel: $TUNNEL_ID
credentials-file: $HOME/.cloudflared/$TUNNEL_ID.json
ingress:
  - hostname: $TUNNEL_HOST
    service: http://127.0.0.1:$PORT
  - service: http_status:404
YML
  echo "$TUNNEL_HOST" > "$STATE/fester-tunnel"
  write_plist "$LABEL_TUN" tunnel "$CLOUDFLARED" tunnel --no-autoupdate --config "$CONFIG" run "$TUNNEL_NAME"
fi
: > "$LOGS/tunnel.log"
launchctl bootstrap "gui/$(id -u)" "$AGENTS/$LABEL_TUN.plist"

say "4/4  Warte auf die Internet-Adresse …"
if [ -z "$TUNNEL_NAME" ]; then
  URL=""
  for _ in $(seq 1 45); do
    URL="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOGS/tunnel.log" | tail -1 || true)"
    [ -n "$URL" ] && break
    sleep 1
  done
  [ -n "$URL" ] || fail "Keine Adresse bekommen. Protokoll: $LOGS/tunnel.log"
else
  URL="https://$TUNNEL_HOST"
  sleep 5
fi

say "Fertig! Deine Gästeseite ist erreichbar unter:"
echo
echo "    $URL/"
echo
echo "Diese Adresse in der App eintragen: Menü → Guest link → Guest page address."
echo "Adresse später wieder anzeigen:   bash $SCRIPT_DIR/status.sh"
