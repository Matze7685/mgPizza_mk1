# Gäste-Speisekarte (Firebase) – Einrichtung

1. https://console.firebase.google.com → Projekt anlegen (Analytics aus).
2. **Build → Firestore Database → Datenbank erstellen** (Produktionsmodus, Region z. B. `eur3`).
3. **Build → Authentication → Anmeldemethode → „Anonym“ aktivieren.** Gäste melden sich damit unsichtbar an (kein Login, keine Mail, kein PIN);
   jedes Gerät bekommt nur eine zufällige Kennung.
4. Tab **Regeln** (Firestore) einfügen und veröffentlichen:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       function signedIn() { return request.auth != null; }
       function isHost(e) { return signedIn() && request.auth.uid == get(/databases/$(db)/documents/events/$(e)).data.get('hostUid', ''); }

       match /events/{event} {
         allow get: if true;                      // nur einzelne Abende per ID, keine Liste aller Abende
         // Abend anlegen/ändern: nur der Gastgeber (ein Abend ohne hostUid, also von früher, wird beim nächsten Veröffentlichen übernommen)
         allow create: if signedIn() && request.resource.data.hostUid == request.auth.uid;
         allow update: if isHost(event)
           || (signedIn() && resource.data.get('hostUid', '') == '' && request.resource.data.hostUid == request.auth.uid);
         allow delete: if isHost(event);

         match /orders/{order} {
           // Lesen: nur die eigene Bestellung (Kennung des Geräts) oder der Gastgeber. Freie Bestellungen (owner leer) darf jeder öffnen und übernehmen.
           allow get: if resource == null || resource.data.get('owner', '') == ''
             || (signedIn() && resource.data.owner == request.auth.uid) || isHost(event);
           allow list: if (signedIn() && resource.data.get('owner', '') == request.auth.uid) || isHost(event);
           allow create: if signedIn() && (request.resource.data.owner == request.auth.uid || isHost(event));
           allow update: if signedIn() && (
               (resource.data.get('owner', '') == '' && request.resource.data.owner == request.auth.uid)
               || (resource.data.owner == request.auth.uid && request.resource.data.owner == request.auth.uid)
               || isHost(event));
           allow delete: if resource == null
             || (signedIn() && resource.data.get('owner', '') == request.auth.uid) || isHost(event);
         }
       }

       // Push bei Gästebestellungen (hosting/mac-mini/pizza-push). Lesen darf beides nur der Mac mini mit seinem Dienstkonto.
       match /pushTokens/{token} {
         // Das iPhone des Gastgebers meldet sich für Push an (nur mit seiner eigenen Kennung)
         allow create, update: if signedIn() && request.resource.data.hostUid == request.auth.uid;
         allow delete: if resource == null || (signedIn() && resource.data.hostUid == request.auth.uid);
       }
       match /pings/{ping} {
         // „Klingel“ der Gästeseite nach Speichern/Löschen: nur Abend, Bestellung, Aktion und Zeitpunkt
         allow create, update: if signedIn()
           && request.resource.data.keys().hasOnly(['at', 'event', 'order', 'action'])
           && request.resource.data.at == request.time
           && request.resource.data.event is string && request.resource.data.order is string;
       }
     }
   }
   ```
   **So funktioniert der Schutz:** Die Gästeseite meldet jedes Gerät anonym an. An jeder Bestellung steht die Kennung (`owner`) des Geräts.
   Nur dieses Gerät kann sie lesen, ändern oder löschen; **fremde Bestellungen sind auf der Gästeseite unsichtbar und serverseitig nicht abrufbar.**
   Der Gastgeber (Kennung als `hostUid` am Abend, wird beim Veröffentlichen in der App gesetzt) sieht und verwaltet alle Bestellungen.
   Handy gewechselt oder Browserdaten gelöscht? In der App unter *Guest link* die Bestellung nach links wischen → *Für neues Gerät freigeben*.
   Eine freigegebene oder alte Bestellung (ohne Kennung) darf das nächste Gerät öffnen und übernehmen – gib sie also erst frei, wenn der Gast bereit ist.
   Die Event-ID im Link ist lang und zufällig (unerratbar), sonst ist nichts geschützt – für einen Pizzaabend okay.
   Hinweis: Einmal im **Regeln-Simulator** testen. Mit den alten, offenen Regeln läuft die neue Seite zwar, schützt aber nichts.
5. **Projekteinstellungen → Allgemein**: *Projekt-ID* und unter *Ihre Apps → Web-App* den *apiKey* notieren (App registrieren, Hosting nicht nötig).
6. In `docs/index.html` oben `PROJECT` und `API_KEY` eintragen, pushen.
7. GitHub → Repo **Settings → Pages → Branch wählen, Ordner `/docs`**. Adresse: `https://<user>.github.io/<repo>/`.
8. In der App: Menü → *Guest link* → Projekt-ID, API-Key und Seitenadresse eintragen (einmalig), Gäste eintragen, *Publish menu*, Link teilen.
9. Später: *Fetch orders* → *Import into menu & toppings* → Zutaten landen in der Einkaufsliste-Funktion.

## Push bei Gästebestellungen

Auf Wunsch schickt der Mac mini dir eine Mitteilung aufs iPhone, sobald ein Gast bestellt, seine Bestellung ändert oder löscht
(z. B. „🍕 Annas 40er · Anna hat bestellt: 2× Margherita (ohne Basilikum)“). Einrichtung:
[`hosting/mac-mini/pizza-push/ANLEITUNG.md`](../hosting/mac-mini/pizza-push/ANLEITUNG.md). Die Regeln oben enthalten dafür
schon `pushTokens` und `pings`.

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
