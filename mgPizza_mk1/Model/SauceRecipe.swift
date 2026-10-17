//
//  SauceRecipe.swift
//  mgPizza_mk1
//

import Foundation
import SwiftData

/// Eine Zutat der Sauce in Prozent bezogen auf die Tomatenmenge (Tomate = 100 %).
struct SauceIngredient: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var percent: Double
}

@Model
class SauceRecipe {
    var uid: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var pizzaCount: Double = 4
    var gramsPerPizza: Double = 80
    var tomatoName: String = "Pelati / San Marzano"
    var ingredients: [SauceIngredient] = SauceRecipe.defaultIngredients
    var rating: Int = 0
    var notes: String = ""

    init(name: String = "", pizzaCount: Double = 4, gramsPerPizza: Double = 80,
         tomatoName: String = "Pelati / San Marzano",
         ingredients: [SauceIngredient] = SauceRecipe.defaultIngredients) {
        self.name = name
        self.pizzaCount = pizzaCount
        self.gramsPerPizza = gramsPerPizza
        self.tomatoName = tomatoName
        self.ingredients = ingredients
    }

    static let defaultIngredients: [SauceIngredient] = [
        SauceIngredient(name: "Salt", percent: 1.5),
        SauceIngredient(name: "Olive Oil", percent: 3.0),
        SauceIngredient(name: "Fresh Basil", percent: 0.8),
        SauceIngredient(name: "Dried Oregano", percent: 0.2),
        SauceIngredient(name: "Garlic", percent: 0.0),
        SauceIngredient(name: "Sugar", percent: 0.0),
    ]

    var displayName: String {
        name.isEmpty ? String(localized: "Sauce \(createdAt.formatted(date: .abbreviated, time: .omitted))") : name
    }

    var totalWeight: Double { pizzaCount * gramsPerPizza }

    var tomatoWeight: Double {
        let factor = 1.0 + ingredients.reduce(0) { $0 + $1.percent } / 100.0
        return totalWeight / factor
    }

    func amount(of ingredient: SauceIngredient) -> Double {
        tomatoWeight * ingredient.percent / 100.0
    }

    var shoppingItems: [(String, String)] {
        [(tomatoName, String(format: "%.0f g", tomatoWeight))]
        + ingredients.filter { $0.percent > 0 }.map { ($0.name, String(format: "%.1f g", amount(of: $0))) }
    }
}
