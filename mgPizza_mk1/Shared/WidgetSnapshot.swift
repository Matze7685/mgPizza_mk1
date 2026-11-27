//
//  WidgetSnapshot.swift
//  mgPizza_mk1
//
//  Wird von App UND Widget-Extension verwendet (Target Membership: beide).
//  Die App legt beim Verlassen eine kleine Zusammenfassung in die gemeinsame App Group,
//  das Homescreen-Widget liest sie. Alle Texte sind schon übersetzt.
//

import Foundation

nonisolated struct WidgetSnapshot: Codable, Hashable {
    struct Step: Codable, Hashable {
        var title: String       // z. B. „Aus dem Kühlschrank“
        var date: Date
        var symbol: String      // SF Symbol
    }

    struct Dough: Codable, Hashable {
        var name: String
        var status: String      // z. B. „Kneten“, leer wenn der Timer läuft
        var steps: [Step]
    }

    struct Event: Codable, Hashable {
        var title: String
        var date: Date
        var detail: String      // z. B. „8 von 12 Gästen haben bestellt“
    }

    var doughs: [Dough] = []
    var event: Event?
    var updated = Date()

    static let appGroup = "group.com.einfachschwimmen.mgPizza-mk1"
    private static let key = "widgetSnapshot_v1"

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }

    /// Nächster Zeitpunkt nach `now` (für den Zeitplan des Widgets)
    func nextStep(after now: Date) -> Step? {
        doughs.flatMap(\.steps).filter { $0.date > now }.min { $0.date < $1.date }
    }
}
