//
//  KneadStep.swift
//  mgPizza_mk1
//

import Foundation

/// Welche Zutat (und welcher Anteil davon) in einem Knetschritt zugegeben wird.
struct KneadAdd: Codable, Hashable {
    var key: String          // "flour", "water", "yeast", "salt", "oil", "sugar"
    var fraction: Double = 1.0
}

/// Ein Schritt in der Knetmaschine, der von Hand gestartet wird.
struct KneadStep: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var detail: String
    var minutes: Double
    var adds: [KneadAdd] = []

    init(title: String, detail: String, minutes: Double, adds: [KneadAdd] = []) {
        self.title = title
        self.detail = detail
        self.minutes = minutes
        self.adds = adds
    }

    // Ältere gespeicherte Schritte haben noch kein "adds"
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decode(String.self, forKey: .detail)
        minutes = try container.decode(Double.self, forKey: .minutes)
        adds = try container.decodeIfPresent([KneadAdd].self, forKey: .adds) ?? []
    }

    /// Zutaten des Schritts – gespeichert oder (bei älteren/importierten Schritten) aus dem Titel abgeleitet
    var effectiveAdds: [KneadAdd] {
        if !adds.isEmpty { return adds }
        let text = title.lowercased()
        if ["start", "mix", "misch"].contains(where: text.contains) {
            return [KneadAdd(key: "water"), KneadAdd(key: "flour"), KneadAdd(key: "yeast")]
        }
        if ["salz", "salt"].contains(where: text.contains) {
            return [KneadAdd(key: "salt"), KneadAdd(key: "oil"), KneadAdd(key: "sugar")]
        }
        if ["öl", "oil"].contains(where: text.contains) { return [KneadAdd(key: "oil")] }
        if ["wasser", "water"].contains(where: text.contains) { return [KneadAdd(key: "water")] }
        return []
    }

    static let defaultPlan: [KneadStep] = [
        KneadStep(title: String(localized: "Mix"), detail: String(localized: "Cold water + yeast, then ~\(90)% of the flour. Slow speed."), minutes: 3,
                  adds: [KneadAdd(key: "water"), KneadAdd(key: "yeast"), KneadAdd(key: "flour", fraction: 0.9)]),
        KneadStep(title: String(localized: "Autolyse"), detail: String(localized: "Machine off – let the flour hydrate."), minutes: 15),
        KneadStep(title: String(localized: "Salt & rest of flour"), detail: String(localized: "Add salt (and sugar) plus the remaining flour."), minutes: 5,
                  adds: [KneadAdd(key: "salt"), KneadAdd(key: "sugar"), KneadAdd(key: "flour", fraction: 0.1)]),
        KneadStep(title: String(localized: "Oil"), detail: String(localized: "Drizzle in the oil slowly (skip if none). Medium speed."), minutes: 2,
                  adds: [KneadAdd(key: "oil")]),
        KneadStep(title: String(localized: "Rest"), detail: String(localized: "Machine off, cover the bowl."), minutes: 10),
        KneadStep(title: String(localized: "Final knead"), detail: String(localized: "Until smooth & windowpane test passes. Dough < 25 °C."), minutes: 2),
    ]

    /// Detroit: hohe Hydration -> ca. 10 % Wasser zurückhalten und später einarbeiten (Bassinage)
    static let detroitPlan: [KneadStep] = [
        KneadStep(title: String(localized: "Mix"), detail: String(localized: "Water (hold back ~\(10)%) + yeast + all the flour. Slow speed."), minutes: 3,
                  adds: [KneadAdd(key: "water", fraction: 0.9), KneadAdd(key: "yeast"), KneadAdd(key: "flour")]),
        KneadStep(title: String(localized: "Autolyse"), detail: String(localized: "Machine off – let the flour hydrate."), minutes: 20),
        KneadStep(title: String(localized: "Salt & knead"), detail: String(localized: "Add salt (and sugar). Slow to medium speed until the dough gets smooth."), minutes: 5,
                  adds: [KneadAdd(key: "salt"), KneadAdd(key: "sugar")]),
        KneadStep(title: String(localized: "Remaining water"), detail: String(localized: "Add the held-back water in small portions, wait until each is absorbed."), minutes: 4,
                  adds: [KneadAdd(key: "water", fraction: 0.1)]),
        KneadStep(title: String(localized: "Oil"), detail: String(localized: "Drizzle in the oil slowly. Medium speed."), minutes: 2,
                  adds: [KneadAdd(key: "oil")]),
        KneadStep(title: String(localized: "Rest"), detail: String(localized: "Machine off, cover the bowl."), minutes: 10),
        KneadStep(title: String(localized: "Final knead"), detail: String(localized: "Sticky is fine – it should pull away from the bowl. Dough < 25 °C."), minutes: 2),
    ]

    static func plan(forStyle style: String) -> [KneadStep] {
        style == "detroit" ? detroitPlan : defaultPlan
    }
}
