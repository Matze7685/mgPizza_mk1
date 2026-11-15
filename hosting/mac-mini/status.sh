#!/bin/bash
# Zeigt, ob Webserver und Tunnel laufen, und die aktuelle Internet-Adresse der Gästeseite.
LOGS="$HOME/Library/Logs/mgpizza"
STATE="$HOME/.mgpizza"
UID_="$(id -u)"

check() { # $1=label $2=Name
  if launchctl print "gui/$UID_/$1" 2>/dev/null | grep -q "state = running"; then
    echo "  ✅ $2 läuft"
  else
    echo "  ❌ $2 läuft NICHT  (Protokoll: $3)"
  fi
}

echo
check de.mgpizza.webserver "Webserver" "$LOGS/webserver.log"
check de.mgpizza.tunnel    "Tunnel   " "$LOGS/tunnel.log"

if curl -fsS -o /dev/null http://127.0.0.1:8080/; then
  echo "  ✅ Seite antwortet lokal (http://127.0.0.1:8080/)"
else
  echo "  ❌ Seite antwortet lokal nicht"
fi

if [ -f "$STATE/fester-tunnel" ]; then
  URL="https://$(cat "$STATE/fester-tunnel")"
else
  URL="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOGS/tunnel.log" 2>/dev/null | tail -1)"
fi

echo
if [ -n "$URL" ]; then
  echo "Adresse der Gästeseite:"
  echo
  echo "    $URL/"
  echo
  echo "Steht in der App noch eine andere Adresse? Dann diese hier eintragen."
else
  echo "Noch keine Internet-Adresse gefunden. Ein paar Sekunden warten und nochmal versuchen."
fi
