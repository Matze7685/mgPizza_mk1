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

    /// Zuletzt bekannte Erlaubnis für Benachrichtigungen (nil = noch unbekannt).
    /// Ist sie aus, klingelt der Knet-Timer ersatzweise in der App (siehe KneadSection).
    private(set) static var isAuthorized: Bool?

    /// Fragt einmalig nach der Erlaubnis (danach ohne Dialog) und merkt sich das Ergebnis.
    static func requestAuthorization(then action: (() -> Void)? = nil) {
        Task {
            do {
                isAuthorized = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            } catch {
                print("Fehler: \(error.localizedDescription)")
                isAuthorized = false
            }
            action?()
        }
    }

    /// Status beim App-Start lesen, ohne zu fragen
    static func refreshAuthorizationStatus() {
        Task {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            isAuthorized = status == .authorized || status == .provisional || status == .ephemeral
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
                body: "\(name): " + recipe.shapingText)
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

    /// Knet-Timer pro Rezept. Der Ton dieser Benachrichtigung ist der einzige Weckton – auch bei offener App
    /// (siehe AppDelegate), damit es nicht doppelt klingelt.
    static func scheduleKneadStep(id: String, title: String, recipe: String, at date: Date) {
        add(id: "knead-\(id)", at: date, title: String(localized: "Knead step done ⏰"),
            body: String(localized: "\(recipe): \(title) is finished – start the next step."), timeSensitive: true)
    }

    static func cancelKneadStep(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["knead-\(id)"])
    }

    /// Plant eine Erinnerung. Ist die Erlaubnis noch nicht geklärt, wird erst gefragt und danach geplant –
    /// vorher ging die allererste Erinnerung verloren (z. B. beim ersten Knetschritt), weil die Erlaubnis
    /// erst nach dem Planen erteilt wurde.
    private static func add(id: String, at date: Date, title: String, body: String, timeSensitive: Bool = false) {
        let schedule = {
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
        if isAuthorized == true {
            schedule()
        } else {
            requestAuthorization { if isAuthorized == true { schedule() } }
        }
    }
}
