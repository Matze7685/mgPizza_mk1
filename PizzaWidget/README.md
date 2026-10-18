# PizzaWidget – Live Activity (Dynamic Island)

Einmalig in Xcode einrichten:

1. **File → New → Target… → Widget Extension**
   - Product Name: `PizzaWidget`
   - Haken bei **Include Live Activity** setzen, die anderen (Control, Configuration Intent) weglassen
   - „Activate scheme?“ → Activate
2. Xcode erzeugt einen Ordner `PizzaWidget` mit Beispieldateien. **Alle erzeugten `.swift`-Dateien löschen**
   (Move to Trash) und stattdessen `PizzaWidget/PizzaLiveActivity.swift` aus diesem Ordner zum Target `PizzaWidget` hinzufügen
   (Rechtsklick auf den Ordner → Add Files… → Target: nur *PizzaWidget*).
3. `mgPizza_mk1/Shared/PizzaActivityAttributes.swift` auswählen → rechts im File Inspector unter
   **Target Membership** zusätzlich **PizzaWidget** anhaken (mgPizza_mk1 bleibt angehakt).
4. Beim Target `PizzaWidget` → General → **Minimum Deployments** auf dieselbe iOS-Version wie die App stellen (26.4).
5. App-Schema auswählen und auf dem iPhone starten.

`NSSupportsLiveActivities` ist in der App bereits eingetragen.
