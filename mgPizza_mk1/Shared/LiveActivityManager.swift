//
//  LiveActivityManager.swift
//  mgPizza_mk1
//

import ActivityKit
import Foundation

/// Startet/aktualisiert die Timer in Dynamic Island und Sperrbildschirm.
/// iOS beendet Live Activities nach max. 8 Std. – Teig-Timer werden daher erst angezeigt,
/// wenn das nächste Ereignis weniger als 8 Std. entfernt ist (Aktualisierung beim Öffnen der App).
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private let maxLead: TimeInterval = 8 * 3600

    private var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    // MARK: Knet-Timer
    func startKnead(title: String, end: Date) {
        show(id: "knead", state: .init(title: title, subtitle: String(localized: "Knead Timer"), endDate: end, symbol: "timer"))
    }

    func endKnead() { end(id: "knead") }

    // MARK: Teig-Timer
    func refreshDough(_ recipes: [RecipeSetupData], now: Date = Date()) {
        for recipe in recipes {
            let id = recipe.uid.uuidString
            guard recipe.isStarted, let next = nextEvent(for: recipe, now: now),
                  next.date.timeIntervalSince(now) < maxLead else {
                end(id: id)
                continue
            }
            show(id: id, state: .init(title: next.title, subtitle: recipe.displayName, endDate: next.date, symbol: next.symbol))
        }
    }

    func endDough(_ recipe: RecipeSetupData) { end(id: recipe.uid.uuidString) }

    private func nextEvent(for recipe: RecipeSetupData, now: Date) -> (title: String, date: Date, symbol: String)? {
        if let out = recipe.fridgeOutDate, recipe.coolTime > 0, out > now {
            return (String(localized: "Out of the fridge"), out, "refrigerator")
        }
        if let serving = recipe.servingDate, serving > now {
            return (String(localized: "Serving"), serving, "fork.knife")
        }
        return nil
    }

    // MARK: Intern
    private func activity(id: String) -> Activity<PizzaActivityAttributes>? {
        Activity<PizzaActivityAttributes>.activities.first { $0.attributes.id == id }
    }

    private func show(id: String, state: PizzaActivityAttributes.ContentState) {
        guard enabled else { return }
        let content = ActivityContent(state: state, staleDate: state.endDate.addingTimeInterval(60))
        if let existing = activity(id: id) {
            Task { await existing.update(content) }
        } else {
            do {
                _ = try Activity.request(attributes: PizzaActivityAttributes(id: id), content: content, pushType: nil)
            } catch {
                print("Live Activity error: \(error.localizedDescription)")
            }
        }
    }

    private func end(id: String) {
        guard let existing = activity(id: id) else { return }
        Task { await existing.end(nil, dismissalPolicy: .immediate) }
    }
}
