# PizzaWidget – Live Activity (Dynamic Island)

Das Widget-Extension-Target `PizzaWidget` ist bereits im Xcode-Projekt eingetragen
(Quellen: `PizzaLiveActivity.swift` + `../mgPizza_mk1/Shared/PizzaActivityAttributes.swift`,
eingebettet in die App unter „Embed Foundation Extensions“). Es ist **kein manueller Schritt in Xcode** mehr nötig.

Falls Xcode beim ersten Bauen meckert:
- Target **PizzaWidget** → *Signing & Capabilities* → Team auswählen (wie bei der App), „Automatically manage signing“ an.
- Auf dem iPhone: Einstellungen → Pizza → **Live-Aktivitäten** an.

Hinweis: Solange die App im Vordergrund ist, zeigt iOS die eigene Live Activity nicht in der Dynamic Island –
sie erscheint, sobald man die App verlässt (und auf dem Sperrbildschirm).
