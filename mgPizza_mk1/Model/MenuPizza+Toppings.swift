//
//  MenuPizza+Toppings.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

extension MenuPizza {
    /// Belag aller Bestellungen zusammengerechnet (gleicher Name + Einheit)
    /// - Parameter sauce: Mit Saucenrezept wird die Tomatensauce in ihre Zutaten aufgeteilt (für die Einkaufsliste)
    static func aggregatedToppings(of onMenu: [MenuPizza], sauce: SauceRecipe? = nil) -> [(key: String, name: String, amount: Double, unit: String)] {
        var totals: [String: (name: String, amount: Double, unit: String)] = [:]
        var order: [String] = []
        // Gleiche Zutat zusammenrechnen, auch wenn sie unterschiedlich heißt („Cooked ham“ ↔ „Schinken“,
        // „Mozzarella (fior di latte)“ ↔ „Mozzarella“) oder in anderer Einheit steht (g ↔ Stück).
        func addPlain(_ name: String, _ amount: Double, _ unit: String) {
            var key = "\(name.lowercased())|\(unit)"
            var amount = amount
            if totals[key] == nil, let match = existingKey(for: name, unit: unit, in: totals, order: order) {
                key = match.key
                if match.unit != unit, let converted = convert(amount, from: unit, to: match.unit, name: name) { amount = converted }
            }
            if totals[key] == nil { order.append(key) }
            totals[key, default: (name, 0, unit)].amount += amount
        }
        func add(_ name: String, _ amount: Double, _ unit: String) {
            if let sauce, isTomatoSauce(name), unit == "g" || unit == "ml" {
                for part in sauce.parts(forSauce: amount) where part.amount > 0 { addPlain(part.name, part.amount, part.unit) }
            } else {
                addPlain(name, amount, unit)
            }
        }
        for pizza in onMenu where pizza.orderCount > 0 {
            for topping in pizza.toppings {
                let count = max(0, pizza.orderCount - (pizza.removedToppings[topping.name] ?? 0))
                if count > 0 { add(topping.name, topping.amount * Double(count), topping.unit) }
            }
        }
        // Zusatzzutaten der Gäste mit Standardmenge pro Pizza (Einstellung „Extra amounts per pizza“)
        for pizza in onMenu where pizza.orderCount > 0 {
            for (name, count) in pizza.guestExtras.sorted(by: { $0.key < $1.key }) where count > 0 {
                let standard = ExtraDefaults.amount(for: name)
                add(name, standard.amount * Double(count), standard.unit)
            }
        }
        return order.compactMap { key -> (key: String, name: String, amount: Double, unit: String)? in
            guard let item = totals[key] else { return nil }
            return (key, item.name, item.amount, item.unit)
        }
    }

    private static func normalized(_ name: String) -> String {
        // Namen im Belag sind oft englische Schlüssel („Cooked ham“), die App zeigt sie übersetzt („Schinken“)
        Bundle.main.localizedString(forKey: name, value: nil, table: nil)
            .lowercased().replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// „Tomatensauce“, „Tomato sauce“, „Pizzasauce“ …
    static func isTomatoSauce(_ name: String) -> Bool {
        let text = normalized(name).replacingOccurrences(of: " ", with: "")
        return ["tomatensauce", "tomatosauce", "pizzasauce", "tomatensoße", "tomatensosse"].contains { text.contains($0) }
    }

    /// Menge für die Einkaufsliste: Gramm/ml ganz, Stück aufgerundet
    static func shoppingAmount(_ amount: Double, unit: String) -> String {
        switch unit {
        case "g", "ml": return formatted(amount >= 10 ? amount.rounded() : (amount * 10).rounded() / 10, unit: unit)
        case "pcs": return formatted(amount.rounded(.up), unit: unit)
        default: return formatted((amount * 4).rounded(.up) / 4, unit: unit)
        }
    }

    /// Alle Zutaten der bestellten Pizzen für die Einkaufsliste (Tomatensauce nach Rezept aufgeteilt)
    static func shoppingItems(of pizzas: [MenuPizza], sauce: SauceRecipe?) -> [(String, String)] {
        aggregatedToppings(of: pizzas, sauce: sauce).map { ($0.name, shoppingAmount($0.amount, unit: $0.unit)) }
    }

    private static func words(_ name: String) -> [String] {
        name.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "/" }).map(String.init)
    }

    /// Schon vorhandener Eintrag für dieselbe Zutat (Namen enthalten sich gegenseitig); gleiche Einheit hat Vorrang
    private static func existingKey(for name: String, unit: String, in totals: [String: (name: String, amount: Double, unit: String)],
                                    order: [String]) -> (key: String, unit: String)? {
        let wanted = normalized(name)
        guard !wanted.isEmpty else { return nil }
        let matches = order.compactMap { key -> (key: String, unit: String)? in
            guard let item = totals[key] else { return nil }
            let have = normalized(item.name)
            // ganze Wörter vergleichen: „Oliven“ passt zu „Schwarze Oliven“, „Tomaten“ aber nicht zu „Tomatensauce“
            let haveWords = Set(words(have)), wantedWords = Set(words(wanted))
            guard !haveWords.isEmpty, haveWords.isSubset(of: wantedWords) || wantedWords.isSubset(of: haveWords) else { return nil }
            // andere Einheit nur, wenn umrechenbar
            if item.unit != unit, convert(1, from: unit, to: item.unit, name: name) == nil { return nil }
            return (key, item.unit)
        }
        return matches.first { $0.unit == unit } ?? matches.first
    }

    /// Gewicht eines Stücks in Gramm für gängige Zutaten (zum Umrechnen zwischen g und Stück)
    private static let pieceGrams: [String: Double] = ["zwiebel": 150, "onion": 150, "knoblauch": 5, "garlic": 5,
                                                       "ei": 60, "egg": 60, "tomate": 100, "paprika": 150]

    private static func convert(_ amount: Double, from: String, to: String, name: String) -> Double? {
        let words = normalized(name).split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
        guard let grams = pieceGrams.first(where: { words.contains($0.key) })?.value else { return nil }
        switch (from, to) {
        case ("g", "pcs"): return amount / grams
        case ("pcs", "g"): return amount * grams
        default: return nil
        }
    }
}
