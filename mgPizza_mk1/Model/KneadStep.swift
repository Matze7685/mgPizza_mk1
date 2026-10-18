//
//  KneadStep.swift
//  mgPizza_mk1
//

import Foundation

/// Ein Schritt in der Knetmaschine, der von Hand gestartet wird.
struct KneadStep: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var detail: String
    var minutes: Double

    static let defaultPlan: [KneadStep] = [
        KneadStep(title: String(localized: "Mix"), detail: String(localized: "Cold water + yeast, then ~\(90)% of the flour. Slow speed."), minutes: 3),
        KneadStep(title: String(localized: "Autolyse"), detail: String(localized: "Machine off – let the flour hydrate."), minutes: 15),
        KneadStep(title: String(localized: "Salt & rest of flour"), detail: String(localized: "Add salt (and sugar) plus the remaining flour."), minutes: 5),
        KneadStep(title: String(localized: "Oil"), detail: String(localized: "Drizzle in the oil slowly (skip if none). Medium speed."), minutes: 2),
        KneadStep(title: String(localized: "Rest"), detail: String(localized: "Machine off, cover the bowl."), minutes: 10),
        KneadStep(title: String(localized: "Final knead"), detail: String(localized: "Until smooth & windowpane test passes. Dough < 25 °C."), minutes: 2),
    ]

    /// Detroit: hohe Hydration -> ca. 10 % Wasser zurückhalten und später einarbeiten (Bassinage)
    static let detroitPlan: [KneadStep] = [
        KneadStep(title: String(localized: "Mix"), detail: String(localized: "Water (hold back ~\(10)%) + yeast + all the flour. Slow speed."), minutes: 3),
        KneadStep(title: String(localized: "Autolyse"), detail: String(localized: "Machine off – let the flour hydrate."), minutes: 20),
        KneadStep(title: String(localized: "Salt & knead"), detail: String(localized: "Add salt (and sugar). Slow to medium speed until the dough gets smooth."), minutes: 5),
        KneadStep(title: String(localized: "Remaining water"), detail: String(localized: "Add the held-back water in small portions, wait until each is absorbed."), minutes: 4),
        KneadStep(title: String(localized: "Oil"), detail: String(localized: "Drizzle in the oil slowly. Medium speed."), minutes: 2),
        KneadStep(title: String(localized: "Rest"), detail: String(localized: "Machine off, cover the bowl."), minutes: 10),
        KneadStep(title: String(localized: "Final knead"), detail: String(localized: "Sticky is fine – it should pull away from the bowl. Dough < 25 °C."), minutes: 2),
    ]

    static func plan(forStyle style: String) -> [KneadStep] {
        style == "detroit" ? detroitPlan : defaultPlan
    }
}
