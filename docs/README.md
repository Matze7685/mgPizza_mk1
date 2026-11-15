# Gäste-Speisekarte (Firebase) – Einrichtung

1. https://console.firebase.google.com → Projekt anlegen (Analytics aus).
2. **Build → Firestore Database → Datenbank erstellen** (Produktionsmodus, Region z. B. `eur3`).
3. Tab **Regeln** einfügen und veröffentlichen:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       match /events/{event} {
         allow read, write: if true;
         match /orders/{order} { allow read, write: if true; }
       }
     }
   }
   ```
   Die Event-ID im Link ist lang und zufällig (unerratbar), sonst ist nichts geschützt – für einen Pizzaabend okay.
4. **Projekteinstellungen → Allgemein**: *Projekt-ID* und unter *Ihre Apps → Web-App* den *apiKey* notieren (App registrieren, Hosting nicht nötig).
5. In `docs/index.html` oben `PROJECT` und `API_KEY` eintragen, pushen.
6. GitHub → Repo **Settings → Pages → Branch wählen, Ordner `/docs`**. Adresse: `https://<user>.github.io/<repo>/`.
7. In der App: Menü → *Guest link* → Projekt-ID, API-Key und Seitenadresse eintragen (einmalig), Gäste eintragen, *Publish menu*, Link teilen.
8. Später: *Fetch orders* → *Import into menu & toppings* → Zutaten landen in der Einkaufsliste-Funktion.

**Alternative zu GitHub Pages:** Die Seite kann auch auf einem Mac mini laufen und über einen Cloudflare Tunnel per https erreichbar sein. Anleitung: [`hosting/mac-mini/ANLEITUNG.md`](../hosting/mac-mini/ANLEITUNG.md).
