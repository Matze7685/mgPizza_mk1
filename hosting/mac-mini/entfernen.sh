#!/bin/bash
# Stoppt Webserver und Tunnel und entfernt den automatischen Start.
# Das Projekt selbst, Caddy und cloudflared bleiben auf dem Mac.
AGENTS="$HOME/Library/LaunchAgents"
for label in de.mgpizza.webserver de.mgpizza.tunnel; do
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  rm -f "$AGENTS/$label.plist"
done
echo "Gästeseite auf diesem Mac gestoppt. Zum erneuten Einrichten: bash hosting/mac-mini/einrichten.sh"
