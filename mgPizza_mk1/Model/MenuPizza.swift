//
//  MenuPizza.swift
//  mgPizza_mk1
//

import Foundation
import SwiftData

/// Belag pro Pizza, z. B. 120 g Mozzarella
struct Topping: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var amount: Double
    var unit: String = "g"      // "g", "ml", "pcs", "tsp"
}

/// Eine Pizza auf der Speisekarte mit Belag und Bestellanzahl
@Model
class MenuPizza {
    var name: String = ""
    var info: String = ""
    var toppings: [Topping] = []
    var isOnMenu: Bool = true
    var orderCount: Int = 0
    /// Zutaten, die Gäste abgewählt haben: Name -> wie oft (für die Einkaufsmenge)
    var removedToppings: [String: Int] = [:]
    /// Zusatzzutaten, die Gäste zu dieser Pizza gewünscht haben: Name -> wie oft
    var guestExtras: [String: Int] = [:]
    var sortIndex: Int = 0
    var isDetroit: Bool = false
    /// Von einem Gast zusammengestellte eigene Pizza (wird beim Import angelegt, gehört nicht zur Speisekarte)
    var isGuestCustom: Bool = false

    init(name: String, info: String = "", toppings: [Topping] = [], sortIndex: Int = 0, isDetroit: Bool = false) {
        self.name = name
        self.info = info
        self.toppings = toppings
        self.sortIndex = sortIndex
        self.isDetroit = isDetroit
    }

    /// Kurzbeschreibung für die Speisekarte: "Tomatensauce, Mozzarella, Basilikum"
    var toppingsText: String {
        toppings.map(\.name).joined(separator: ", ")
    }

    static func formatted(_ amount: Double, unit: String) -> String {
        let value = amount.formatted(.number.precision(.fractionLength(0...2)))
        switch unit {
        case "pcs": return "\(value) \(String(localized: "pcs"))"
        case "tsp": return "\(value) \(String(localized: "tsp"))"
        default: return "\(value) \(unit)"
        }
    }
}

// MARK: - Reibekäse
extension MenuPizza {
    /// Geriebener Hartkäse (Parmesan/Grana) zum Bestreuen: ca. 10 g pro Pizza
    static var gratedCheese: Topping { Topping(name: String(localized: "Parmesan (grated)"), amount: 10) }

    /// Hat die Pizza schon Reibekäse (Parmesan, Grana, Pecorino …)?
    var hasGratedCheese: Bool {
        toppings.contains { topping in
            let name = Bundle.main.localizedString(forKey: topping.name, value: nil, table: nil).lowercased()
            return ["parmesan", "parmigiano", "grana", "pecorino", "reibekäse", "grated cheese"].contains { name.contains($0) }
        }
    }

    /// Einmalig: jeder gespeicherten Pizza Reibekäse geben (außer Pizzen ohne Käse wie Marinara und Gäste-Pizzen)
    static func addGratedCheeseIfNeeded(into context: ModelContext) {
        let key = "addGratedCheese_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let all = (try? context.fetch(FetchDescriptor<MenuPizza>())) ?? []
        for pizza in all where !pizza.isGuestCustom && !pizza.hasGratedCheese && pizza.name.lowercased() != "marinara" {
            pizza.toppings.append(gratedCheese)
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}

// MARK: - Startauswahl
extension MenuPizza {
    private static let seedKey = "seedMenuPizzas_v1"

    /// Klassiker als Startpunkt – Mengen pro Pizza (ca. 30–33 cm), alles anpassbar
    /// Ein paar weitere Klassiker (einmalig, ohne vorhandene Pizzen zu verändern oder doppelt anzulegen)
    static func seedMoreIfNeeded(into context: ModelContext) {
        let key = "seedMenuPizzas_v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let existing = (try? context.fetch(FetchDescriptor<MenuPizza>())) ?? []
        let names = Set(existing.map { $0.name.lowercased() })
        var index = (existing.map(\.sortIndex).max() ?? 0) + 1
        let sauce = String(localized: "Tomato sauce")
        let mozza = String(localized: "Mozzarella (fior di latte)")
        let more: [MenuPizza] = [
            MenuPizza(name: "Marinara", info: String(localized: "Without cheese"), toppings: [
                Topping(name: sauce, amount: 90), Topping(name: String(localized: "Garlic"), amount: 1, unit: "pcs"),
                Topping(name: String(localized: "Oregano"), amount: 0.5, unit: "tsp"),
                Topping(name: String(localized: "Olive Oil"), amount: 5, unit: "ml")]),
            MenuPizza(name: "Funghi", toppings: [
                Topping(name: sauce, amount: 80), Topping(name: mozza, amount: 100),
                Topping(name: String(localized: "Mushrooms"), amount: 70)]),
            MenuPizza(name: "Schinken", toppings: [
                Topping(name: sauce, amount: 80), Topping(name: mozza, amount: 100),
                Topping(name: String(localized: "Cooked ham"), amount: 60)]),
            MenuPizza(name: "Capricciosa", toppings: [
                Topping(name: sauce, amount: 80), Topping(name: mozza, amount: 100),
                Topping(name: String(localized: "Cooked ham"), amount: 40),
                Topping(name: String(localized: "Mushrooms"), amount: 40),
                Topping(name: String(localized: "Artichokes"), amount: 40),
                Topping(name: String(localized: "Black olives"), amount: 15)]),
            MenuPizza(name: "Peperoni", info: String(localized: "Spicy"), toppings: [
                Topping(name: sauce, amount: 80), Topping(name: mozza, amount: 100),
                Topping(name: String(localized: "Pepperoni"), amount: 50)]),
            MenuPizza(name: "Rucola-Schinken", toppings: [
                Topping(name: sauce, amount: 70), Topping(name: mozza, amount: 100),
                Topping(name: String(localized: "Parma ham"), amount: 40),
                Topping(name: String(localized: "Rocket"), amount: 15),
                Topping(name: String(localized: "Parmesan"), amount: 15)]),
        ]
        for pizza in more where !names.contains(pizza.name.lowercased()) {
            pizza.sortIndex = index
            index += 1
            context.insert(pizza)
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }

    static func seedIfNeeded(into context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }
        let sauce = String(localized: "Tomato sauce")
        let mozza = String(localized: "Mozzarella (fior di latte)")
        let pizzas: [MenuPizza] = [
            MenuPizza(name: "Margherita", info: String(localized: "The classic"), toppings: [
                Topping(name: sauce, amount: 80), Topping(name: mozza, amount: 110),
                Topping(name: String(localized: "Fresh Basil"), amount: 3, unit: "pcs"),
                Topping(name: String(localized: "Olive Oil"), amount: 5, unit: "ml")]),
            MenuPizza(name: "Salame", toppings: [
                Topping(name: sauce, amount: 80), Topping(name: mozza, amount: 100),
                Topping(name: String(localized: "Salami"), amount: 50)], sortIndex: 1),
            MenuPizza(name: "Diavola", info: String(localized: "Spicy"), toppings: [
                Topping(name: sauce, amount: 80), Topping(name: mozza, amount: 100),
                Topping(name: String(localized: "Spicy salami (Spianata)"), amount: 50),
                Topping(name: String(localized: "Chili flakes"), amount: 0.25, unit: "tsp")], sortIndex: 2),
            MenuPizza(name: "Prosciutto e Funghi", toppings: [
                Topping(name: sauce, amount: 80), Topping(name: mozza, amount: 100),
                Topping(name: String(localized: "Cooked ham"), amount: 50),
                Topping(name: String(localized: "Mushrooms"), amount: 60)], sortIndex: 3),
            MenuPizza(name: "Tonno e Cipolla", toppings: [
                Topping(name: sauce, amount: 80), Topping(name: mozza, amount: 100),
                Topping(name: String(localized: "Tuna"), amount: 60),
                Topping(name: String(localized: "Red onion"), amount: 0.25, unit: "pcs")], sortIndex: 4),
            MenuPizza(name: "Quattro Formaggi", info: String(localized: "Without tomato"), toppings: [
                Topping(name: mozza, amount: 70), Topping(name: String(localized: "Gorgonzola"), amount: 30),
                Topping(name: String(localized: "Parmesan"), amount: 15), Topping(name: String(localized: "Fontina / Taleggio"), amount: 30)], sortIndex: 5),
            MenuPizza(name: "Detroit Red Top", info: String(localized: "Square pan pizza with crispy cheese rim"), toppings: [
                Topping(name: String(localized: "Cheese (Brick / young Gouda)"), amount: 200),
                Topping(name: String(localized: "Pepperoni"), amount: 60),
                Topping(name: sauce, amount: 150)], sortIndex: 6, isDetroit: true),
        ]
        pizzas.forEach { context.insert($0) }
        try? context.save()
        UserDefaults.standard.set(true, forKey: seedKey)
    }
}
