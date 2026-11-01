//
//  TimerModel.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 13.08.26.
//

import UserNotifications

class NotificationModel {
    
    
    func scheduleTimerNotification(in seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Timer abgelaufen!"
        content.body = "Deine Zeit ist um."
        content.sound = .default

        // Trigger, der nach X Sekunden auslöst (repeats: false bedeutet nur einmal)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)

        // Request erstellen mit einer eindeutigen ID
        let request = UNNotificationRequest(identifier: "TimerNotification", content: content, trigger: trigger)

        // Zum System hinzufügen
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Fehler beim Planen: \(error.localizedDescription)")
            }
        }
    }
}

/// Erinnerungen für Teig raus / Servierzeit und die Knet-Timer.
enum DoughNotifications {
    static let fridgeWarningLead: TimeInterval = 3600   // 1 Std. vorher erinnern

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("Fehler: \(error.localizedDescription)")
            }
        }
    }

    static func schedule(for recipe: RecipeSetupData) {
        cancel(for: recipe)
        let id = recipe.uid.uuidString
        let name = recipe.displayName
        if let out = recipe.fridgeOutDate, recipe.coolTime > 0 {
            add(id: "\(id)-fridge-warn", at: out.addingTimeInterval(-fridgeWarningLead),
                title: String(localized: "Dough out in 1 hour"),
                body: String(localized: "\(name): get ready to take the dough out of the fridge."))
            add(id: "\(id)-fridge", at: out,
                title: String(localized: "Take the dough out!"),
                body: String(localized: "\(name): take the dough out of the fridge and portion it into balls."))
        }
        if let serving = recipe.servingDate {
            add(id: "\(id)-serving", at: serving,
                title: String(localized: "Pizza time 🍕"),
                body: String(localized: "\(name): the dough is ready – heat the oven and start baking."))
        }
    }

    static func cancel(for recipe: RecipeSetupData) {
        let id = recipe.uid.uuidString
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["\(id)-fridge-warn", "\(id)-fridge", "\(id)-serving"])
    }

    /// Knet-Timer pro Rezept, mit Ton (auch wenn die App offen ist, siehe AppDelegate)
    static func scheduleKneadStep(id: String, title: String, recipe: String, at date: Date) {
        add(id: "knead-\(id)", at: date, title: String(localized: "Knead step done ⏰"),
            body: String(localized: "\(recipe): \(title) is finished – start the next step."), timeSensitive: true)
    }

    static func cancelKneadStep(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["knead-\(id)"])
    }

    private static func add(id: String, at date: Date, title: String, body: String, timeSensitive: Bool = false) {
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if timeSensitive { content.interruptionLevel = .timeSensitive }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
            if let error = error {
                print("Fehler beim Planen: \(error.localizedDescription)")
            }
        }
    }
}
