//
//  SeedImporter.swift
//  mgPizza_mk1
//
//  Einmaliger Import der bisherigen Rezepte aus "Pizzarezepte.numbers".
//

import SwiftData
import SwiftUI

enum SeedImporter {
    private static let doneKey = "seedPizzarezepte_v1"

    // MARK: - Daten aus der Tabelle

    private struct Dough {
        let date: String              // Rezeptdatum
        let balls: Double
        let ballWeight: Double
        let flour: Double
        let semola: Double
        let water: Double
        let yeast: Double             // Trockenhefe in g
        let salt: Double
        let roomTime: Double
        let roomTemp: Double
        let coolTime: Double
        let coolTemp: Double
        var oil: Double = 0
        var sugar: Double = 0
        var knead: [Double]? = nil    // Halo Core: Start S1, Salz S1, Warten, Schluss S2 (Minuten)
        let meal: String              // Mahlzeit "dd.MM.yy HH:mm" oder "dd.MM.yy"
        var flourName: String = ""
        var notes: String = ""
    }

    private static let doughs: [Dough] = [
        Dough(date: "21.08.26", balls: 6, ballWeight: 350, flour: 1288, semola: 120, water: 773, yeast: 0.47, salt: 38.7,
              roomTime: 12, roomTemp: 27, coolTime: 65, coolTemp: 4, knead: [3, 5, 10, 1], meal: "24.08.26 18:30",
              notes: "Wasser: 1/3 Eis.\nTeig extrem trocken nach Halo Core -> ca. 100 ml Wasser dazu gegeben und nochmal 5 Min. Halo Core."),
        Dough(date: "23.08.26", balls: 2, ballWeight: 400, flour: 441, semola: 50, water: 294, yeast: 0.18, salt: 14.7,
              roomTime: 12, roomTemp: 27, coolTime: 11, coolTemp: 4, knead: [3, 4, 10, 1], meal: "24.08.26 18:30"),
        Dough(date: "24.08.26", balls: 2, ballWeight: 350, flour: 400, semola: 0, water: 300, yeast: 4, salt: 10,
              roomTime: 2, roomTemp: 27, coolTime: 18, coolTemp: 4, oil: 10, meal: "25.08.26", flourName: "Glutenfrei Mehl",
              notes: "Glutenfreies Mehl. Lauwarmes Wasser, 10 g Olivenöl. Kühlzeit 16–20 Std."),
        Dough(date: "26.08.26", balls: 8, ballWeight: 300, flour: 1305, semola: 167, water: 883, yeast: 0.58, salt: 44,
              roomTime: 4, roomTemp: 27, coolTime: 93, coolTemp: 4, knead: [3, 4, 10, 1], meal: "30.08.26"),
        Dough(date: "30.08.26", balls: 8, ballWeight: 300, flour: 1229, semola: 217, water: 911, yeast: 0.46, salt: 43,
              roomTime: 9, roomTemp: 27, coolTime: 23, coolTemp: 4, knead: [3, 4, 10, 2], meal: "31.08.26"),
        Dough(date: "02.09.26", balls: 25, ballWeight: 300, flour: 3764, semola: 753, water: 2846, yeast: 0.99, salt: 136,
              roomTime: 10, roomTemp: 27, coolTime: 44, coolTemp: 4, knead: [3, 4, 10, 2], meal: "04.09.26"),
        Dough(date: "05.09.26", balls: 20, ballWeight: 300, flour: 3011, semola: 603, water: 2277, yeast: 0.92, salt: 108,
              roomTime: 10, roomTemp: 27, coolTime: 24, coolTemp: 4, knead: [3, 4, 10, 2], meal: "06.09.26"),
        Dough(date: "09.09.26", balls: 4, ballWeight: 330, flour: 786, semola: 0, water: 511, yeast: 0.38, salt: 23.6,
              roomTime: 9, roomTemp: 27, coolTime: 0, coolTemp: 4, knead: [3, 4, 10, 2], meal: "09.09.26"),
        Dough(date: "09.09.26", balls: 3, ballWeight: 410, flour: 732, semola: 0, water: 476, yeast: 0.53, salt: 22,
              roomTime: 6, roomTemp: 27, coolTime: 0, coolTemp: 4, knead: [3, 4, 10, 2], meal: "09.09.26"),
        Dough(date: "10.10.26", balls: 4, ballWeight: 330, flour: 868, semola: 0, water: 434, yeast: 0.38, salt: 17.4,
              roomTime: 10, roomTemp: 27, coolTime: 19, coolTemp: 4, oil: 24, sugar: 8.7, knead: [3, 4, 10, 2], meal: "11.10.26",
              notes: "Wasser 50 %. 26 ml Olivenöl (≈ 24 g) und 8,7 g Zucker mit dem Salz zugegeben."),
        Dough(date: "10.10.26", balls: 4, ballWeight: 330, flour: 868, semola: 0, water: 462, yeast: 0.38, salt: 16.8,
              roomTime: 10, roomTemp: 27, coolTime: 19, coolTemp: 4, oil: 24, sugar: 8.7, knead: [3, 4, 10, 2], meal: "11.10.26",
              notes: "Wasser 55 %. 26 ml Olivenöl (≈ 24 g) und 8,7 g Zucker mit dem Salz zugegeben."),
    ]

    private struct Sauce {
        let date: String
        let pizzas: Double
        let onion: Double, garlic: Double, oil: Double, tomatoes: Double, paste: Double
        let salt: Double, pepper: Double, sugar: Double   // Teelöffel
        var extras: [(String, Double, SauceUnit)] = []
        var notes: String
    }

    private static let sauces: [Sauce] = [
        Sauce(date: "24.08.26", pizzas: 4, onion: 50, garlic: 1, oil: 10, tomatoes: 200, paste: 30, salt: 0.5, pepper: 0.25, sugar: 0.5,
              extras: [("Kapern", 7, .piece), ("Sardelle", 1, .piece)], notes: "Zusatz: 7 Kapern, 1 Sardelle, Balsamico (Menge nach Gefühl)."),
        Sauce(date: "26.08.26", pizzas: 8, onion: 140, garlic: 2, oil: 20, tomatoes: 400, paste: 50, salt: 1, pepper: 0.5, sugar: 1,
              extras: [("Balsamico-Essig", 20, .gram)], notes: "Zusatz: Basilikum, Oregano (nach Gefühl), 20 g Balsamico-Essig."),
        Sauce(date: "30.08.26", pizzas: 8, onion: 200, garlic: 2, oil: 20, tomatoes: 400, paste: 50, salt: 1, pepper: 0.5, sugar: 1,
              extras: [("Kürbiskernöl", 20, .gram)], notes: "Zusatz: Basilikum, Oregano (nach Gefühl), 20 g Kürbiskernöl."),
        Sauce(date: "09.09.26", pizzas: 8, onion: 100, garlic: 1, oil: 20, tomatoes: 400, paste: 65, salt: 1, pepper: 0.5, sugar: 1,
              extras: [("Kürbiskernöl", 60, .gram)], notes: "Zusatz: Basilikum, Oregano (nach Gefühl), 60 g Kürbiskernöl."),
        Sauce(date: "11.10.26", pizzas: 8, onion: 67, garlic: 1, oil: 20, tomatoes: 400, paste: 120, salt: 1, pepper: 0.5, sugar: 1,
              extras: [("Kürbiskernöl", 60, .gram)], notes: "Zusatz: Basilikum, Oregano (nach Gefühl), 60 g Kürbiskernöl, Kapern."),
    ]

    // MARK: - Import

    @MainActor
    static func importIfNeeded(into context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }

        for d in doughs { context.insert(makeDough(d)) }
        for s in sauces { context.insert(makeSauce(s)) }

        try? context.save()
        UserDefaults.standard.set(true, forKey: doneKey)
    }

    private static func makeDough(_ d: Dough) -> RecipeSetupData {
        let totalFlour = d.flour + d.semola
        let pct = { (grams: Double) in (grams / totalFlour * 1000).rounded() / 10 }   // 1 Nachkommastelle

        let recipe = RecipeSetupData(doughBallsCount: d.balls, doughWeight: d.ballWeight,
                                     waterRatio: pct(d.water), saltRatio: pct(d.salt),
                                     yeastSelection: 1,                 // Trockenhefe
                                     fridgeTimeMode: "MAN",
                                     roomTemp: d.roomTemp, roomTime: d.roomTime,
                                     coolTemp: d.coolTemp, coolTime: d.coolTime,
                                     dateSelection: date(d.meal),
                                     oilRatio: pct(d.oil), sugarRatio: pct(d.sugar),
                                     kneadSteps: d.knead.map { haloCoreSteps($0) } ?? glutenFreeSteps,
                                     name: "\(d.date) · \(Int(d.balls))× \(Int(d.ballWeight)) g" + (d.flourName.isEmpty ? "" : " · \(d.flourName)"))
        recipe.createdAt = date(d.date)

        // Hefe-Korrektur so setzen, dass die App genau die damals verwendete Hefemenge anzeigt
        let calculated = recipe.yeast()
        if calculated > 0 {
            recipe.yeastCorrection = (d.yeast / calculated * 100).rounded()
        }

        let flourName = d.flourName.isEmpty ? "Mehl" : d.flourName
        var original = "Original aus Tabelle: \(fmt(d.flour)) g \(flourName)"
        if d.semola > 0 { original += " + \(fmt(d.semola)) g Semola" }
        original += ", \(fmt(d.water)) g Wasser, \(fmt(d.yeast)) g Trockenhefe, \(fmt(d.salt)) g Salz."
        var lines = [original]
        if d.semola > 0 { lines.append("Mehl in der App = Mehl + Semola.") }
        if !d.notes.isEmpty { lines.append(d.notes) }
        recipe.notes = lines.joined(separator: "\n")
        return recipe
    }

    private static func haloCoreSteps(_ m: [Double]) -> [KneadStep] {
        [
            KneadStep(title: "Start (Stufe 1)", detail: "Wasser, Mehl, Hefe", minutes: m[0],
                      adds: [KneadAdd(key: "water"), KneadAdd(key: "flour"), KneadAdd(key: "yeast")]),
            KneadStep(title: "Salz (Stufe 1)", detail: "Salz zugeben (ggf. Öl, Zucker)", minutes: m[1],
                      adds: [KneadAdd(key: "salt"), KneadAdd(key: "oil"), KneadAdd(key: "sugar")]),
            KneadStep(title: "Warten", detail: "Maschine aus", minutes: m[2]),
            KneadStep(title: "Schluss (Stufe 2)", detail: "Fertig kneten", minutes: m[3]),
        ]
    }

    private static let glutenFreeSteps: [KneadStep] = [
        KneadStep(title: "Trocken mischen", detail: "Mehl u. Hefe trocken rühren", minutes: 1,
                  adds: [KneadAdd(key: "flour"), KneadAdd(key: "yeast")]),
        KneadStep(title: "Wasser (Stufe 2)", detail: "Lauwarmes Wasser nach und nach zugeben", minutes: 3,
                  adds: [KneadAdd(key: "water")]),
        KneadStep(title: "Öl & Salz", detail: "Öl und Salz zugeben, Halo Core", minutes: 4,
                  adds: [KneadAdd(key: "oil"), KneadAdd(key: "salt")]),
        KneadStep(title: "Ruhen", detail: "1 Std. ruhen lassen, dann Ballen formen (in Öl) und kalt gären 16–20 Std. 2 Std. vorher raus.", minutes: 60),
    ]

    private static func makeSauce(_ s: Sauce) -> SauceRecipe {
        let perPizza = { (amount: Double) in amount / s.pizzas }
        var ingredients: [SauceIngredient] = [
            SauceIngredient(name: "Zwiebel", percent: perPizza(s.onion), unit: .gram),
            SauceIngredient(name: "Knoblauchzehe", percent: perPizza(s.garlic), unit: .piece),
            SauceIngredient(name: "Öl", percent: perPizza(s.oil), unit: .gram),
            SauceIngredient(name: "Tomatenmark", percent: perPizza(s.paste), unit: .gram),
            SauceIngredient(name: "Salz", percent: perPizza(s.salt), unit: .teaspoon),
            SauceIngredient(name: "Pfeffer", percent: perPizza(s.pepper), unit: .teaspoon),
            SauceIngredient(name: "Zucker", percent: perPizza(s.sugar), unit: .teaspoon),
        ]
        ingredients += s.extras.map { SauceIngredient(name: $0.0, percent: perPizza($0.1), unit: $0.2) }

        // Ohne %-Zutaten entspricht die Tomatenmenge genau Pizzen × Gramm pro Pizza
        let sauce = SauceRecipe(name: "Sauce \(s.date)", pizzaCount: s.pizzas,
                                gramsPerPizza: s.tomatoes / s.pizzas,
                                tomatoName: "Tomaten gestückelt", ingredients: ingredients)
        sauce.createdAt = date(s.date)
        sauce.notes = s.notes
        return sauce
    }

    private static func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = text.count > 8 ? "dd.MM.yy HH:mm" : "dd.MM.yy"
        return formatter.date(from: text) ?? Date()
    }

    private static func fmt(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "de_DE")))
    }
}
