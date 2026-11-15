# Gäste-Speisekarte (Firebase) – Einrichtung

1. https://console.firebase.google.com → Projekt anlegen (Analytics aus).
2. **Build → Firestore Database → Datenbank erstellen** (Produktionsmodus, Region z. B. `eur3`).
3. Tab **Regeln** einfügen und veröffentlichen:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       match /events/{event} {
         allow get, write: if true;   // nur einzelne Abende per ID, keine Liste aller Abende
         match /orders/{order} { allow read, write: if true; }
       }
     }
   }
   ```
   Die Event-ID im Link ist lang und zufällig (unerratbar), sonst ist nichts geschützt – für einen Pizzaabend okay.
   `get` statt `read` sorgt dafür, dass niemand die Liste aller Abende abrufen kann: Wer einen Link hat, sieht nur diesen einen Abend.
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
