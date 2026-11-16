# Gäste-Speisekarte (Firebase) – Einrichtung

1. https://console.firebase.google.com → Projekt anlegen (Analytics aus).
2. **Build → Firestore Database → Datenbank erstellen** (Produktionsmodus, Region z. B. `eur3`).
3. Tab **Regeln** einfügen und veröffentlichen:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       function sha(k) { return hashing.sha256(k).toHexString().lower(); }
       function proofPath(e, id) { return /databases/$(db)/documents/events/$(e)/proofs/$(id); }
       // Gültiger Nachweis: wird im selben Schritt geschrieben (neuer Nonce) und passt zum Hash des Besitzers bzw. Gastgebers
       function proved(e, id, hash) {
         return existsAfter(proofPath(e, id))
           && getAfter(proofPath(e, id)).data.nonce != resource.data.get('nonce', '')
           && sha(getAfter(proofPath(e, id)).data.key) == hash;
       }
       function hostHash(e) { return get(/databases/$(db)/documents/events/$(e)).data.get('hostHash', '#'); }

       match /events/{event} {
         allow get: if true;       // nur einzelne Abende per ID, keine Liste aller Abende
         allow create: if true;
         // Abend ändern: nur der Gastgeber (oder solange der Abend noch keinen Gastgeber-Hash hat)
         allow update, delete: if resource.data.get('hostHash', '') == ''
           || proved(event, '_event', resource.data.hostHash);

         match /proofs/{id} { allow write: if true; allow read: if false; }   // Schlüssel sind nie lesbar

         match /orders/{order} {
           allow read: if true;      // alle sehen alle Bestellungen (nur ansehen)
           allow create: if true;
           // Ändern: Gerät des Gasts, Gastgeber, oder (alte/freigegebene Bestellung ohne Kennung) das erste Gerät, das speichert
           allow update: if resource.data.get('ownerHash', '') == ''
             || (proved(event, order, resource.data.ownerHash) && request.resource.data.ownerHash == resource.data.ownerHash
                 && request.resource.data.nonce == getAfter(proofPath(event, order)).data.nonce)
             || (proved(event, order, hostHash(event)));
           // Löschen: Gerät des Gasts oder Gastgeber (alte Bestellungen ohne Kennung nur der Gastgeber)
           allow delete: if resource == null
             || (resource.data.get('ownerHash', '') != '' && proved(event, order, resource.data.ownerHash))
             || proved(event, order, hostHash(event));
         }
       }
     }
   }
   ```
   **So funktioniert der Schutz:** Jedes Gästegerät erzeugt beim ersten Besuch einen zufälligen Schlüssel (nur im Browser, kein Login).
   An der Bestellung steht nur dessen Hash. Zum Ändern/Löschen schickt die Seite den Schlüssel als nicht lesbaren „Nachweis“ im selben
   Schritt mit; die Regeln prüfen ihn serverseitig. Fremde Bestellungen sind nur sichtbar. Der Gastgeber hat einen eigenen Schlüssel in der App
   (Hash am Abend) und kann so jede Bestellung löschen oder freigeben (Menü → Guest link → Bestellung nach links wischen).
   Eine freigegebene oder alte Bestellung (ohne Kennung) übernimmt das nächste Gerät, das sie speichert.
   Die Event-ID im Link ist lang und zufällig (unerratbar), sonst ist nichts geschützt – für einen Pizzaabend okay.
   Hinweis: Einmal im **Regeln-Simulator** der Firebase-Konsole testen. Ohne die neuen Regeln läuft alles weiter wie bisher, nur ohne Schutz.
4. **Projekteinstellungen → Allgemein**: *Projekt-ID* und unter *Ihre Apps → Web-App* den *apiKey* notieren (App registrieren, Hosting nicht nötig).
5. In `docs/index.html` oben `PROJECT` und `API_KEY` eintragen, pushen.
6. GitHub → Repo **Settings → Pages → Branch wählen, Ordner `/docs`**. Adresse: `https://<user>.github.io/<repo>/`.
7. In der App: Menü → *Guest link* → Projekt-ID, API-Key und Seitenadresse eintragen (einmalig), Gäste eintragen, *Publish menu*, Link teilen.
8. Später: *Fetch orders* → *Import into menu & toppings* → Zutaten landen in der Einkaufsliste-Funktion.

## Mehrere Abende / Anlässe

- Jeder Abend hat einen eigenen Link. Titel und Datum kommen aus der Speisekarte (Plan → Event), dazu optional ein
  Begrüßungstext (z. B. „Wir feiern Annas 40er!“). Die Gästeseite zeigt Titel, Datum und Text statt fest „Pizza“.
- *Guest link → New evening (new link)* legt einen neuen Abend an; der bisherige bleibt erhalten.
- *All evenings* zeigt alle Abende (kommende und vergangene) mit Gästen, Bestellungen und Status. Antippen wechselt
  zu dem Abend, nach rechts wischen öffnet oder kopiert den Link, nach links wischen blendet ihn in der App aus.
  *Open guest page* öffnet die Seite des aktuellen Abends im Browser.
- *Orders closed* + *Publish menu*: Gäste sehen ihre Bestellungen noch, können aber nichts mehr ändern.
- Die Übersicht liegt nur in der App. Gäste sehen nie eine Liste anderer Abende.

**Alternative zu GitHub Pages:** Die Seite kann auch auf einem Mac mini laufen und über einen Cloudflare Tunnel per https erreichbar sein. Anleitung: [`hosting/mac-mini/ANLEITUNG.md`](../hosting/mac-mini/ANLEITUNG.md).
