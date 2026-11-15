//
//  DoughAnnouncer.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

/// Sagt Teig-Ereignisse (1 Std. vorher, Teig raus, Servieren) über den Lautsprecher / HomePod an.
/// Funktioniert nur, solange die App läuft (Vordergrund oder aktiv im Hintergrund, z. B. mit Ofen-Fühler).
/// Die normale Benachrichtigung kommt in jedem Fall.
@MainActor
final class DoughAnnouncer {
    static let shared = DoughAnnouncer()

    @AppStorage("doughSpeak") var isEnabled: Bool = false

    private var context: ModelContext?
    private var timer: Timer?
    private var lastCheck = Date()

    func start(context: ModelContext) {
        self.context = context
        guard timer == nil else { return }
        lastCheck = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            MainActor.assumeIsolated { DoughAnnouncer.shared.check() }
        }
    }

    private func check() {
        let now = Date()
        defer { lastCheck = now }
        guard isEnabled, let context else { return }
        let descriptor = FetchDescriptor<RecipeSetupData>(predicate: #Predicate { $0.isStarted == true || $0.isInProgress == true })
        guard let recipes = try? context.fetch(descriptor) else { return }

        for recipe in recipes {
            for (date, text, isKnead) in events(for: recipe) where date > lastCheck && date <= now {
                // Knet-Ansage erst nach dem Weckton, damit sich beides nicht überschneidet
                OvenSpeaker.shared.announce(text, delay: isKnead ? KneadAlarm.ringDuration + 0.5 : 0.5)
            }
        }
    }

    private func events(for recipe: RecipeSetupData) -> [(Date, String, Bool)] {
        let name = recipe.displayName
        var result: [(Date, String, Bool)] = []
        if let end = recipe.kneadStepEnd, let step = recipe.currentKneadStep {
            result.append((end, String(localized: "\(name): \(step.title) is finished. Start the next step."), true))
        }
        guard recipe.isStarted else { return result }
        if let out = recipe.fridgeOutDate, recipe.coolTime > 0 {
            result.append((out.addingTimeInterval(-DoughNotifications.fridgeWarningLead),
                           String(localized: "\(name): the dough comes out of the fridge in one hour."), false))
            result.append((out, String(localized: "\(name): take the dough out of the fridge and portion it now."), false))
        }
        if let serving = recipe.servingDate {
            result.append((serving, String(localized: "\(name): the dough is ready. Time to heat the oven."), false))
        }
        return result
    }
}
