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
