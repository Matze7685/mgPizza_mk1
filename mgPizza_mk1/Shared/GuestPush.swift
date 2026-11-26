//
//  GuestPush.swift
//  mgPizza_mk1
//

import UIKit
import UserNotifications

/// Push bei Gästebestellungen: Das iPhone meldet sein Push-Token in Firestore an (`pushTokens/<token>`, mit der
/// Gastgeber-Kennung). Pizza-Push auf dem Mac mini (hosting/mac-mini/pizza-push) schickt darüber eine Nachricht,
/// sobald ein Gast bestellt, ändert oder löscht.
enum GuestPush {
    static let enabledKey = "guestPushEnabled"
    static let statusKey = "guestPushStatus"
    private static let tokenKey = "guestPushToken"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Xcode-Builds (Debug) bekommen Push über Apples Testserver, TestFlight/App Store über den normalen
    static var sandbox: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static var service: GuestOrderService {
        let defaults = UserDefaults.standard
        return GuestOrderService(project: (defaults.string(forKey: "fbProject") ?? GuestFirebaseDefaults.project).trimmingCharacters(in: .whitespaces),
                                 apiKey: (defaults.string(forKey: "fbKey") ?? GuestFirebaseDefaults.apiKey).trimmingCharacters(in: .whitespaces))
    }

    private static func setStatus(_ text: String) {
        UserDefaults.standard.set(text, forKey: statusKey)
    }

    /// Einschalten: Erlaubnis für Mitteilungen holen und bei Apple registrieren (Token kommt im AppDelegate an)
    @MainActor
    static func enable() async {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else {
            setStatus(String(localized: "Notifications are turned off for this app in the iOS settings."))
            return
        }
        setStatus(String(localized: "Registering …"))
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Beim App-Start: neu registrieren, das Token kann sich ändern
    @MainActor
    static func refreshIfEnabled() {
        if isEnabled { UIApplication.shared.registerForRemoteNotifications() }
    }

    static func didRegister(deviceToken: Data) {
        guard isEnabled else { return }
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let old = UserDefaults.standard.string(forKey: tokenKey)
        Task {
            do {
                try await service.savePushToken(token, sandbox: sandbox)
                if let old, old != token { try? await service.deletePushToken(old) }
                UserDefaults.standard.set(token, forKey: tokenKey)
                setStatus(String(localized: "Active. You get a notification when a guest orders, changes or deletes."))
            } catch {
                setStatus(error.localizedDescription)
            }
        }
    }

    static func didFail(_ error: Error) {
        setStatus(String(localized: "Push registration failed: \(error.localizedDescription)"))
    }

    /// Ausschalten: Token in Firestore entfernen, der Mac mini schickt dann nichts mehr an dieses iPhone
    static func disable() async {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            try? await service.deletePushToken(token)
            UserDefaults.standard.removeObject(forKey: tokenKey)
        }
        setStatus("")
    }
}
