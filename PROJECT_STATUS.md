# mgPizza – Projektstand (Übergabe)

iOS-App (SwiftUI, SwiftData, iOS 26.4) zum Planen von Pizzateig & Sauce. UI-Sprache Englisch, Deutsch über `Localizable.xcstrings`
(neue Texte immer mit deutscher Übersetzung eintragen). Projekt nutzt klassische Xcode-Gruppen: **neue Dateien müssen in
`project.pbxproj` eingetragen werden** (PBXBuildFile, PBXFileReference, Gruppe, Sources-Phase). Kein Xcode in der Cloud – Code wird
ungetestet gepusht, der Nutzer baut selbst.

## Tabs
Aktiv (Hero-Karte + kompakte Zeilen, Ofen) · Rezepte (Umschalter Teig/Sauce) · Speisekarte (Planen/Bestellungen/Einkaufsliste). Settings per Zahnrad (Sheet), neues Rezept per „+“.
Rezeptdetail: nur Bereich der aktuellen Phase aufgeklappt, Tipps/Feedback/Rezeptwerte unter „Mehr“.

## Wichtige Dateien
- `Model/RecipeSetupData.swift` – Teigrezept (@Model): Berechnung (Mehl/Wasser/Salz/Öl/Zucker/Hefe-Formel + Hefe-Korrektur),
  Stil round/detroit (Pfannenmaße/Teigdicke), Zeitmodi MAN/AUTO/OUT (Datum für „aus dem Kühlschrank“ + „Servieren“),
  Ablauf/Phasen (Zutaten → Kneten → Kühlschrank → Raum → Servieren), Knet-Timer pro Rezept, Durchgänge bei > Knetmaschinen-Kapazität (Settings, Std. 2500 g).
- `Model/KneadStep.swift` – Knetschritte inkl. Zutaten-Anteilen (`adds`), Standard- und Detroit-Plan.
- `RecipeDetailView.swift` – geführter Ablauf im Rezept; `TimerView/KneadTimerView.swift` – Knet-Abschnitt + Alarm.
- `RecipeContainer/*` – Setup-Assistent (3 Schritte + Ergebnis). START → Rezept beginnen & per `Shared/AppRouter.swift` hineinwechseln.
- `Model/SauceRecipe.swift`, `SauceView.swift` – Saucen (Einheiten %, g, ml, Stk., TL) + Zutaten-Tipps.
- `Model/MenuPizza.swift`, `MenuView.swift` – Speisekarte für Gäste (Text/PDF teilen, Bestellungen, Belag → Einkaufsliste).
- `ShoppingListView.swift` – Einkaufsliste + Auswahl-Sheet.
- `OrdersFoldView.swift` – geteilte Ansicht (Bestellungen › „Geteilte Ansicht“) für faltbares iPhone in Laptop-Stellung: oben aktuelle Pizza groß (Gast, Pizza, Zutaten mit Mengen, Zusatzzutaten grün, abgewählte rot), unten Reihenfolge der Zubereitung (verschiebbar, abhaken, „Pizza fertig“ → nächste). Reihenfolge + geladene Gästebestellungen pro Abend in UserDefaults (`foldQueue_<id>`, `foldOrders_<id>`, `PrepQueueStore`). Teilung exakt in Bildschirmmitte; iOS hat keine Scharnier-API, daher manuell geöffnet.
- `NotificationModel.swift` – Erinnerungen (Teig raus −1 h / raus / Servieren, Knetschritte).
- `Shared/LiveActivityManager.swift`, `Shared/PizzaActivityAttributes.swift`, `PizzaWidget/` – Dynamic Island (Widget-Extension-Target `PizzaWidget` ist im Projekt eingetragen, siehe `PizzaWidget/README.md`).
- `Shared/DoughAnnouncer.swift`, `Bluetooth/OvenSpeaker.swift` – Sprachansagen über AirPlay/HomePod (nur solange App läuft).
- `Shared/VoiceControl.swift` – Sprachsteuerung (Deutsch/Englisch) für den Knetablauf: „nächster Schritt“, „Start“, „zurück“, „wiederholen“, „wie lange“, „Kühlschrank“, „Sprachsteuerung aus“. Mikrofon-Schalter im Knet-Abschnitt.
- `ActivityView.swift` enthält `DoughStatusBar` (oben angeheftete Statusleiste nur während Zutaten/Kneten, Option „Always show dough status“); `MainView` schiebt Timer beim Verlassen der App in die Dynamic Island.
- Knet-Alarm: einzige Tonquelle ist die Benachrichtigung (auch im Vordergrund, AppDelegate); `KneadAlarm.ring()` nur als Ersatz, wenn Benachrichtigungen aus sind. `KneadAlarm.finish` meldet jedes Schrittende einmal (Sprachansage). Timer-Stände werden sofort gespeichert (`RecipeSetupData.persist()`), damit sie ein Beenden im Hintergrund überleben.
- `Shared/GuestOrders.swift` + `docs/` – Gäste-Speisekartenlink (Firebase Firestore REST, Webseite `docs/index.html`, Einrichtung `docs/README.md`); Import setzt Bestellmengen + abgewählte Zutaten (`MenuPizza.removedToppings`). Mehrere Abende: lokale Übersicht `GuestEvenings` (UserDefaults `guestEvenings_v1`), aktueller Abend in `menuEventID`/`menuTitle`/`menuDate`/`guestIntro`/`guestOrdersClosed`.
- `Shared/TimerStatusView.swift` – Kontrolle geplanter Erinnerungen/Berechtigungen.
- `Shared/SeedImporter.swift` – einmaliger Import der Rezepte aus „Pizzarezepte.numbers“.
- `Bluetooth/OvenMonitor.swift` – Ooni Digital Temperature Hub (BLE, Name „Ooni_DT_Hub“, Service 69400001-…, Notify 69400002-…,
  Bytes 2–3 = Fühler 1 in °C Int16 LE, 4–5 = Fühler 2), Zielalarm, 45-Min-Abschalt-Erinnerung, State Restoration für Sperrbildschirm.
- `Bluetooth/BLEDebugView.swift` – Bluetooth-Testansicht.

## Offene Ideen / Wünsche des Nutzers
- Home-Assistant-Anbindung für zuverlässige HomePod-Ansagen (Nutzer: „später“).
- Optional: Schritt „Teiglinge formen“ nach dem Kneten.
- Optional: Bestellseite (Link) für Gäste statt Antwort per Nachricht.
- ESP32-Eigenbau-Hub mit vorhandenem Ooni-Fühler (Thermistor, Klinke) – wartet auf Widerstands-Messwerte.
- Bluetooth im Sperrbildschirm: Fix (State Restoration) noch vom Nutzer zu testen.
