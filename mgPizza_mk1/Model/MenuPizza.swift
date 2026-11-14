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
    var sortIndex: Int = 0
    var isDetroit: Bool = false

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

// MARK: - Startauswahl
extension MenuPizza {
    private static let seedKey = "seedMenuPizzas_v1"

    /// Klassiker als Startpunkt – Mengen pro Pizza (ca. 30–33 cm), alles anpassbar
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
