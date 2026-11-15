//
//  SauceRecipe.swift
//  mgPizza_mk1
//

import Foundation
import SwiftData

enum SauceUnit: String, Codable, CaseIterable, Identifiable {
    case percent = "%"
    case gram = "g"
    case milliliter = "ml"
    case piece = "pcs"
    case teaspoon = "tsp"
    var id: String { rawValue }
}

/// Eine Zutat der Sauce.
/// - Einheit `%`: `percent` ist der Anteil bezogen auf die Tomatenmenge (Tomate = 100 %).
/// - Einheit g / ml / Stück / TL: `percent` ist die Menge pro Pizza und wird mit der Pizza-Anzahl skaliert.
struct SauceIngredient: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var percent: Double
    var unit: SauceUnit = .percent

    init(name: String, percent: Double, unit: SauceUnit = .percent) {
        self.name = name
        self.percent = percent
        self.unit = unit
    }

    // Ältere gespeicherte Zutaten haben noch keine Einheit
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        percent = try container.decode(Double.self, forKey: .percent)
        unit = try container.decodeIfPresent(SauceUnit.self, forKey: .unit) ?? .percent
    }
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
        SauceIngredient(name: String(localized: "Salt"), percent: 1.5),
        SauceIngredient(name: String(localized: "Olive Oil"), percent: 3.0),
        SauceIngredient(name: String(localized: "Fresh Basil"), percent: 0.8),
        SauceIngredient(name: String(localized: "Dried Oregano"), percent: 0.2),
        SauceIngredient(name: String(localized: "Garlic"), percent: 0.0),
        SauceIngredient(name: String(localized: "Onion"), percent: 0.0, unit: .piece),
        SauceIngredient(name: String(localized: "Sugar"), percent: 0.0),
    ]

    var displayName: String {
        name.isEmpty ? String(localized: "Sauce \(createdAt.formatted(date: .abbreviated, time: .omitted))") : name
    }

    var totalWeight: Double { pizzaCount * gramsPerPizza }

    var tomatoWeight: Double {
        let factor = 1.0 + ingredients.filter { $0.unit == .percent }.reduce(0) { $0 + $1.percent } / 100.0
        return totalWeight / factor
    }

    /// Menge für die aktuelle Pizza-Anzahl (in g bei %, sonst in der Einheit der Zutat)
    func amount(of ingredient: SauceIngredient) -> Double {
        switch ingredient.unit {
        case .percent: return tomatoWeight * ingredient.percent / 100.0
        default: return ingredient.percent * pizzaCount
        }
    }

    func formattedAmount(of ingredient: SauceIngredient) -> String {
        let value = amount(of: ingredient)
        switch ingredient.unit {
        case .percent, .gram: return String(format: "%.1f g", value)
        case .milliliter: return String(format: "%.0f ml", value)
        case .piece: return String(format: "%g %@", (value * 4).rounded() / 4, String(localized: "pcs"))
        case .teaspoon: return String(format: "%g %@", (value * 4).rounded() / 4, String(localized: "tsp"))
        }
    }

    var shoppingItems: [(String, String)] {
        [(tomatoName, String(format: "%.0f g", tomatoWeight))]
        + ingredients.filter { $0.percent > 0 }.map { ($0.name, formattedAmount(of: $0)) }
    }
}
