# Pizza-Push: Mitteilung aufs iPhone bei Gästebestellungen

Sobald ein Gast auf der Gästeseite **bestellt, seine Bestellung ändert oder löscht**, bekommst du eine Push-Nachricht,
auch wenn die App geschlossen ist. Zum Beispiel:

> 🍕 Annas 40er
> Anna hat die Bestellung geändert: 3× Margherita + Ananas (ohne Basilikum)

## So funktioniert es

1. Die Gästeseite legt nach jedem Speichern oder Löschen eine kleine „Klingel“ in Firebase ab (nur: welcher Abend,
   welche Bestellung, wann).
2. **Pizza-Push** läuft im Hintergrund auf dem Mac mini und schaut alle 15 Sekunden nach neuen Klingeln. Es holt die Bestellung,
   vergleicht sie mit dem letzten Stand und erkennt so neu / geändert / gelöscht. Was du selbst in der App änderst, meldet es nicht.
3. Die Nachricht geht direkt über Apple an dein iPhone. Dafür hat die App ihr Push-Token in Firebase hinterlegt.

Kosten: keine. Das sind etwa 6.000 Lesevorgänge pro Tag, Firebase erlaubt im kostenlosen Tarif 50.000.
Der Mac mini muss laufen und du musst dort angemeldet sein (wie beim Webserver).

## Einrichten (einmalig, ca. 15 Minuten)

### 1. Firebase-Schlüssel für den Mac mini

Firebase-Konsole → Zahnrad **Projekteinstellungen** → Tab **Dienstkonten** → **Neuen privaten Schlüssel generieren**.
Es wird eine Datei wie `mgpizza-app-firebase-adminsdk-xxxxx.json` in *Downloads* gespeichert.

Diese Datei ist ein Generalschlüssel für dein Firebase-Projekt: nicht weitergeben, nicht ins Repo legen.
Das Einrichtungsskript kopiert sie nach `~/.mgpizza/push`, danach kannst du sie aus *Downloads* löschen.

### 2. Apple-Push-Schlüssel

1. [developer.apple.com/account](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Keys** → **+**.
2. Name z. B. `Pizza-Push`, Haken bei **Apple Push Notifications service (APNs)** → *Configure* →
   Umgebung **Sandbox & Production** → speichern → **Continue** → **Register** → **Download**.
3. Die Datei heißt `AuthKey_ABCD123456.p8` (die Buchstaben sind die Schlüssel-ID). Apple lässt sie **nur einmal** herunterladen.
   Bitte den Namen nicht ändern, das Skript liest die ID daraus.

Prüfe in Xcode einmal: Projekt → Target *mgPizza_mk1* → **Signing & Capabilities**. Dort muss **Push Notifications** stehen.
Falls nicht: **+ Capability** → *Push Notifications*.

### 3. Firestore-Regeln aktualisieren

Die Regeln in [`docs/README.md`](../../../docs/README.md) (Schritt 4) komplett neu einfügen und veröffentlichen.
Neu sind die Abschnitte `pushTokens` und `pings`.

### 4. Gästeseite aktualisieren

Die Gästeseite `docs/index.html` sendet die Klingel. Wenn sie auf dem Mac mini läuft: `bash hosting/mac-mini/aktualisieren.sh`.
Bei GitHub Pages reicht das Zusammenführen auf GitHub.

### 5. App: Push einschalten

App neu aus Xcode aufs iPhone spielen → Menü → **Guest link** → **Push bei Gästebestellungen** einschalten → Mitteilungen erlauben.
Darunter steht danach „Aktiv …“. Steht dort ein Fehler, sind meist Projekt-ID/API-Key leer oder die Regeln noch alt.

Push kommt nur für Abende, die von **diesem** iPhone veröffentlicht wurden. Einen älteren Abend einmal mit *Publish menu* neu veröffentlichen.

### 6. Pizza-Push auf dem Mac mini starten

Im Terminal auf dem Mac mini, im Projektordner:

```
git pull
bash hosting/mac-mini/pizza-push/einrichten.sh ~/Downloads/mgpizza-app-firebase-adminsdk-xxxxx.json ~/Downloads/AuthKey_ABCD123456.p8
```

(Tipp: Statt die Namen zu tippen, die Datei aus dem Finder ins Terminal-Fenster ziehen.)

Das Skript schickt zuerst eine **Test-Nachricht** an dein iPhone und startet Pizza-Push dann im Hintergrund.
Es startet nach jedem Neustart des Macs von selbst.

## Nützliche Befehle

| Was | Befehl |
|---|---|
| Protokoll ansehen | `tail -f ~/Library/Logs/mgpizza/push.log` |
| Test-Nachricht schicken | `python3 ~/.mgpizza/push/pizza_push.py --test` |
| Nach einem Update neu starten | `bash hosting/mac-mini/pizza-push/einrichten.sh` |
| Ausschalten | `bash hosting/mac-mini/pizza-push/einrichten.sh --aus` |

## Wenn es nicht klappt

- **Test sagt „kein Gerät angemeldet“**: In der App Push einschalten (Schritt 5) und das Skript nochmal starten.
- **„Push fehlgeschlagen (403 InvalidProviderToken)“**: Schlüssel-ID oder Team passen nicht. Die `.p8`-Datei mit ihrem
  Originalnamen nochmal angeben.
- **„Push fehlgeschlagen (400 BadDeviceToken)“** bei einer App aus TestFlight/App Store: Das Gerät wird automatisch entfernt.
  Einfach in der App Push aus- und wieder einschalten.
- **„Firestore … 403“**: Das Dienstkonto gehört zu einem anderen Firebase-Projekt als die App.
- **Gast bestellt, aber nichts passiert**: Läuft die neue Gästeseite (Schritt 4)? Im Protokoll muss eine Zeile mit dem Namen des Gastes erscheinen.
