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
        KneadStep(title: "Mix", detail: "Cold water + yeast, then ~90% of the flour. Slow speed.", minutes: 3),
        KneadStep(title: "Autolyse", detail: "Machine off – let the flour hydrate.", minutes: 15),
        KneadStep(title: "Salt & rest of flour", detail: "Add salt (and sugar) plus the remaining flour.", minutes: 5),
        KneadStep(title: "Oil", detail: "Drizzle in the oil slowly (skip if none). Medium speed.", minutes: 2),
        KneadStep(title: "Rest", detail: "Machine off, cover the bowl.", minutes: 10),
        KneadStep(title: "Final knead", detail: "Until smooth & windowpane test passes. Dough < 25 °C.", minutes: 2),
    ]
}
