#!/bin/bash
# Holt die neueste Version der Gästeseite von GitHub.
# Der Webserver liefert sofort die neue Datei aus, ein Neustart ist nicht nötig.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO"
echo "Hole neueste Version in $REPO …"
git pull --ff-only
echo
echo "Fertig. Gäste sehen die neue Seite, sobald sie die Seite neu laden."
