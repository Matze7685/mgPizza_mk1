# Gästeseite auf dem Mac mini hosten (mit Cloudflare Tunnel)

Diese Anleitung macht deinen Mac mini zum Server für die Gäste-Speisekarte (`docs/index.html`).
Gäste erreichen die Seite danach **von überall** über eine sichere **https-Adresse**.
Am Router musst du nichts einstellen, und es kostet nichts.

**So funktioniert es, kurz erklärt:**

- Ein kleiner **Webserver** (Programm „Caddy“) liefert die Seite auf dem Mac mini aus, nur intern.
- Ein **Cloudflare Tunnel** (Programm „cloudflared“) baut von deinem Mac aus eine Verbindung zu Cloudflare auf.
  Cloudflare gibt dir dafür eine https-Adresse und leitet Besucher durch diesen Tunnel zu deinem Mac.
- Beide Programme starten **automatisch**, sobald der Mac mini läuft und du angemeldet bist.
- Die Bestellungen laufen wie bisher über **Firebase**. Daran ändert sich nichts.

> ⚠️ **Wichtig:** Die Seite ist nur erreichbar, solange der Mac mini **eingeschaltet und wach** ist
> und Internet hat. Ist er aus, sehen Gäste eine Fehlerseite von Cloudflare.

---

## Welchen Weg nehmen?

| | **Weg A: Schnell-Tunnel** (empfohlen zum Start) | **Weg B: Eigene Domain** |
|---|---|---|
| Kosten | kostenlos | Tunnel kostenlos, aber eigene Domain nötig (ca. 5–15 € pro Jahr) |
| Konto | kein Cloudflare-Konto nötig | kostenloses Cloudflare-Konto |
| Adresse | z. B. `https://lustige-worte-1234.trycloudflare.com` | z. B. `https://pizza.meinedomain.de` |
| Nach Neustart des Macs | **neue Adresse**, muss in der App neu eingetragen werden | bleibt immer gleich |

Für einen Pizzaabend reicht **Weg A** völlig. Wichtig ist nur: Wenn der Mac mini neu gestartet wurde,
schaust du vor dem Verschicken des Links kurz nach der aktuellen Adresse (Schritt 7).
Cloudflare nennt den Schnell-Tunnel selbst „zum Testen“: Es gibt keine Garantie, dass er immer läuft,
und höchstens 200 gleichzeitige Anfragen. Für ein paar Gäste ist das kein Problem.

---

## Schritt 1: Mac mini vorbereiten (einmalig)

Damit die Seite auch erreichbar ist, wenn niemand am Mac sitzt:

1. **Ruhezustand verhindern:**
   Apple-Menü  → **Systemeinstellungen** → **Energie** (bei manchen Versionen „Energie sparen“):
   - **„Automatischen Ruhezustand verhindern, wenn der Bildschirm aus ist“** einschalten.
   - **„Nach Stromausfall automatisch starten“** einschalten.
   - (Der Bildschirm darf ruhig ausgehen, das ist kein Problem.)
2. **Automatisch anmelden:**
   Systemeinstellungen → **Benutzer:innen & Gruppen** → **„Automatisch anmelden als“** → deinen Benutzer wählen.
   Nur so starten Webserver und Tunnel nach einem Neustart von selbst.
   *(Ist das Feld grau, ist „FileVault“ eingeschaltet. Dann musst du dich nach einem Neustart einmal
   selbst anmelden, danach läuft alles automatisch.)*

## Schritt 2: Homebrew installieren (einmalig)

Homebrew ist ein Programm, mit dem man andere Programme bequem installiert.

1. Öffne das Programm **Terminal** (Spotlight: `⌘ + Leertaste`, „Terminal“ tippen, Enter).
2. Prüfe, ob Homebrew schon da ist:
   ```
   brew --version
   ```
   Kommt eine Versionsnummer, weiter mit Schritt 3.
3. Sonst diesen Befehl einfügen und Enter drücken (er kommt von der offiziellen Seite https://brew.sh):
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
   Du wirst nach deinem Mac-Passwort gefragt. Beim Tippen siehst du keine Zeichen, das ist normal.
4. **Ganz wichtig:** Am Ende zeigt Homebrew unter **„Next steps“** zwei bis drei Befehle an.
   Diese bitte genau so kopieren und ausführen. Danach das Terminal-Fenster schließen und ein neues öffnen.
5. Nochmal `brew --version` eingeben. Jetzt sollte eine Versionsnummer kommen.

## Schritt 3: Projekt auf den Mac mini holen (einmalig)

Im Terminal:

```
cd ~
git clone https://github.com/Matze7685/mgPizza_mk1.git
```

Fragt der Mac, ob er die „Entwicklerwerkzeuge“ installieren soll: **Installieren** klicken, warten,
dann den `git clone`-Befehl nochmal ausführen.

> **Wichtig:** Das Projekt muss direkt in deinem Benutzerordner liegen (also `~/mgPizza_mk1`),
> **nicht** im Ordner „Schreibtisch“, „Dokumente“, „Downloads“ oder in iCloud.
> Auf diese Ordner dürfen Hintergrundprogramme unter macOS nicht zugreifen, dann bliebe die Seite leer.

## Schritt 4 (Weg A): Alles einrichten mit einem Befehl

```
cd ~/mgPizza_mk1
bash hosting/mac-mini/einrichten.sh
```

Das Skript

1. installiert Caddy und cloudflared,
2. richtet den Webserver ein und startet ihn,
3. richtet den Cloudflare Tunnel ein und startet ihn,
4. zeigt dir am Ende die **Adresse deiner Gästeseite** an, z. B.
   `https://lustige-worte-1234.trycloudflare.com/`

Das dauert beim ersten Mal ein paar Minuten. Am Ende steht **„Fertig!“**.

## Schritt 5: Testen

1. Öffne die angezeigte Adresse auf deinem **Handy im Mobilfunknetz** (WLAN aus), um sicherzugehen,
   dass sie von außen erreichbar ist. Ohne Event-Link steht dort nur „Link unvollständig.“, das ist richtig so.
2. Weiter mit Schritt 6, dann den Gästelink aus der App testen.

Die allererste Anfrage kann ein paar Sekunden dauern, bis der Tunnel überall bekannt ist.

## Schritt 6: Adresse in der App eintragen

In der App: **Menü → Guest link → Guest page address** → die Adresse aus Schritt 4 eintragen
(mit `https://` und `/` am Ende). Dann wie gewohnt **Publish menu** und **Send guest link**.

## Schritt 7: Adresse später wieder anzeigen (Weg A)

Nach einem Neustart des Mac mini (oder Stromausfall) bekommt der Schnell-Tunnel eine **neue Adresse**.
So siehst du die aktuelle Adresse und ob alles läuft:

```
cd ~/mgPizza_mk1
bash hosting/mac-mini/status.sh
```

Steht dort eine andere Adresse als in der App, trag die neue in der App ein und schick den Link neu.

---

## Seite aktualisieren

Wenn sich die Gästeseite im Repo geändert hat (z. B. nach einem gemergten Pull Request):

```
cd ~/mgPizza_mk1
bash hosting/mac-mini/aktualisieren.sh
```

Das holt die neueste Version von GitHub. Ein Neustart ist nicht nötig. Gäste sehen die neue Seite,
sobald sie die Seite neu laden. Die Adresse ändert sich dabei nicht.

## Alles wieder ausschalten

```
cd ~/mgPizza_mk1
bash hosting/mac-mini/entfernen.sh
```

Webserver und Tunnel werden gestoppt und starten nicht mehr automatisch.
Zum Wiedereinschalten einfach Schritt 4 nochmal ausführen.

---

## Weg B: Feste Adresse mit eigener Domain (optional)

Nur nötig, wenn dich die wechselnde Adresse stört. Voraussetzung: Du besitzt eine Domain
(z. B. `meinedomain.de`) und sie ist bei Cloudflare eingebunden.

1. Kostenloses Konto auf https://dash.cloudflare.com anlegen.
2. **Domain hinzufügen** („Add a domain“), den kostenlosen Tarif „Free“ wählen und den Anweisungen folgen.
   Meist musst du bei deinem Domain-Anbieter die **Nameserver** auf die zwei Cloudflare-Nameserver ändern.
   Das kann bis zu einem Tag dauern. Weiter erst, wenn Cloudflare die Domain als **„Active“** anzeigt.
   *(Alternativ kannst du eine Domain direkt bei Cloudflare kaufen, dann entfällt das.)*
3. Zuerst Weg A einmal ausführen (Schritt 4), damit alles installiert ist.
4. Bei Cloudflare anmelden. Im Terminal:
   ```
   cloudflared tunnel login
   ```
   Es öffnet sich der Browser. Dort deine Domain anklicken und **Authorize** wählen.
5. Einrichten mit Tunnel-Name und gewünschter Adresse (beides frei wählbar, hier `pizza` und `pizza.meinedomain.de`):
   ```
   cd ~/mgPizza_mk1
   bash hosting/mac-mini/einrichten.sh pizza pizza.meinedomain.de
   ```
   Das legt den Tunnel an, erstellt den DNS-Eintrag bei Cloudflare und stellt den automatischen Start um.
6. `https://pizza.meinedomain.de/` in der App eintragen. Diese Adresse bleibt ab jetzt immer gleich.

Zurück zu Weg A: einfach `bash hosting/mac-mini/einrichten.sh` ohne Zusätze ausführen.

---

## Muss in Firebase eine Domain eingetragen werden?

**Nein.** Ich habe die Seite geprüft: Sie spricht Firebase (Firestore) direkt über die normale Web-Schnittstelle
mit Projekt-ID und API-Key an und nutzt **keine Firebase-Anmeldung** („Authentication“).
Die Liste „Autorisierte Domains“ in Firebase gilt nur für die Anmeldung und ist hier egal.
Die Firestore-Regeln (siehe `docs/README.md`) prüfen keine Domain.

Nur **eine Ausnahme**: Falls du den API-Key in der Google Cloud Console irgendwann selbst
auf bestimmte Websites beschränkt hast („Anwendungseinschränkungen → Websites“), musst du dort die neue
Adresse ergänzen, bei Weg A als `https://*.trycloudflare.com/*`, bei Weg B als `https://pizza.meinedomain.de/*`.
Wenn du das nie eingestellt hast, ist nichts zu tun.

Die bisherige Adresse über GitHub Pages funktioniert übrigens weiter, falls sie eingeschaltet ist.
Welche Seite die Gäste bekommen, bestimmt nur die Adresse, die du in der App einträgst.

---

## Fehlerhilfe

| Problem | Lösung |
|---|---|
| `brew: command not found` | Schritt 2, Punkt 4: die „Next steps“-Befehle von Homebrew ausführen, neues Terminal-Fenster öffnen. |
| „Der Projektordner liegt in Schreibtisch/Dokumente …“ | Projekt nach `~/mgPizza_mk1` klonen (Schritt 3) und dort das Skript starten. |
| Gäste sehen eine Cloudflare-Fehlerseite (Fehler 1033 oder 530) | Mac mini ist aus, schläft oder hat kein Internet. Mac prüfen, dann `status.sh` ausführen. |
| Link funktioniert nach Neustart nicht mehr (Weg A) | Normal: neue Adresse. `status.sh` ausführen und die neue Adresse in der App eintragen. |
| `status.sh` zeigt ❌ | Einfach `einrichten.sh` nochmal ausführen. Hilft das nicht, das angezeigte Protokoll ansehen, z. B. `tail -n 30 ~/Library/Logs/mgpizza/tunnel.log` |
| Weg A: Tunnel startet nicht, Fehler mit „config“ | Liegt eine Datei `~/.cloudflared/config.yml` (oder `.yaml`) herum, stört sie den Schnell-Tunnel. Umbenennen, dann `einrichten.sh` erneut ausführen. |
| Weg B: Fehler beim DNS-Eintrag („record already exists“) | Im Cloudflare-Dashboard unter **DNS** den alten Eintrag für `pizza` löschen und `einrichten.sh pizza pizza.meinedomain.de` erneut ausführen. |
| Bestellungen kommen nicht an, Seite lädt aber | Liegt nicht am Mac mini. In `docs/index.html` `PROJECT` und `API_KEY` prüfen und ob in der App *Publish menu* gemacht wurde. |

## Was die Skripte auf dem Mac anlegen

- `~/Library/LaunchAgents/de.mgpizza.webserver.plist` und `de.mgpizza.tunnel.plist`: der automatische Start
- `~/Library/Logs/mgpizza/`: Protokolle von Webserver und Tunnel
- `~/.mgpizza/`: Einstellungen für Weg B
- Der Webserver ist nur auf dem Mac selbst erreichbar (`127.0.0.1:8080`), nicht im Heimnetz.
  Von außen geht alles nur über den Tunnel.
