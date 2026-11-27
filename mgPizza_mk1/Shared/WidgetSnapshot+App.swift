//
//  WidgetSnapshot+App.swift
//  mgPizza_mk1
//
//  Nur App: Zusammenfassung für das Homescreen-Widget aus Rezepten und Anlässen bauen.
//

import Foundation
import SwiftData
import WidgetKit

extension WidgetSnapshot {
    @MainActor
    static func update(context: ModelContext) {
        let recipes = (try? context.fetch(FetchDescriptor<RecipeSetupData>())) ?? []
        let now = Date()
        var snapshot = WidgetSnapshot()
        snapshot.doughs = recipes.filter(\.isActive).map { recipe in
            var steps: [Step] = []
            if recipe.isStarted {
                if let out = recipe.fridgeOutDate, recipe.coolTime > 0, out > now {
                    steps.append(Step(title: String(localized: "Out of the fridge"), date: out, symbol: "refrigerator"))
                }
                if let serving = recipe.servingDate {
                    steps.append(Step(title: String(localized: "Serving"), date: serving, symbol: "fork.knife"))
                }
            }
            let status: String = switch recipe.phase(now: now) {
            case .ingredients: String(localized: "Weigh ingredients")
            case .knead: String(localized: "Knead")
            default: ""
            }
            return Dough(name: recipe.displayName, status: status, steps: steps)
        }
        if let next = GuestEvenings.all.filter({ !$0.isPast }).min(by: { $0.date < $1.date }) {
            let detail: String
            if let counts = next.fixedCounts {
                detail = String(localized: "\(counts.values.reduce(0, +)) pizzas")
            } else if let orders = next.orderCount, !next.guests.isEmpty {
                detail = String(localized: "\(orders) of \(next.guests.count) guests ordered")
            } else {
                detail = String(localized: "\(next.guests.count) guests")
            }
            snapshot.event = Event(title: next.title, date: next.date, detail: detail)
        }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
