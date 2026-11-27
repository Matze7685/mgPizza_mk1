//
//  mgPizza_mk1App.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 28.07.26.
//

import SwiftData
import SwiftUI
import UserNotifications

/// Zeigt Benachrichtigungen (mit Ton) auch an, wenn die App gerade offen ist (z. B. Knet-Timer).
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        DoughNotifications.refreshAuthorizationStatus()
        _ = OvenMonitor.shared   // Bluetooth sofort wiederherstellen, auch wenn iOS die App im Hintergrund startet
        GuestPush.refreshIfEnabled()
        return true
    }

    // Schnellaktionen am App-Symbol: eigener Scene-Delegate (SwiftUI reicht sie sonst nicht weiter)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    // Push bei Gästebestellungen (GuestPush): Token von Apple an Firestore weitergeben
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        GuestPush.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        GuestPush.didFail(error)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Alle Erinnerungen – auch der Knet-Timer – klingeln über den Ton der Benachrichtigung.
        // Die App selbst klingelt nur noch, wenn Benachrichtigungen ausgeschaltet sind (KneadSection).
        // Vorher klingelten App-Alarm und Benachrichtigung getrennt, was trotz Entprellung doppelt zu hören war.
        completionHandler([.banner, .sound, .list])
    }
}

/// Fehler beim Öffnen der Datenbank (nil = alles in Ordnung)
enum StoreProblem {
    static var message: String?
}

@main
struct mgPizza_mk1App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var ovenMonitor = OvenMonitor.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RecipeSetupData.self,
            SauceRecipe.self,
            ShoppingItem.self,
            MenuPizza.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Datenbank lässt sich nicht öffnen (z. B. nach einer unpassenden Modelländerung): nicht abstürzen,
            // sondern vorübergehend ohne gespeicherte Daten starten und oben einen Hinweis zeigen.
            // Die Datei bleibt unangetastet, ein korrigiertes Update kann sie wieder öffnen.
            StoreProblem.message = error.localizedDescription
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memory])
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(TimerLogic())
                .environmentObject(ovenMonitor)
        }
        .modelContainer(sharedModelContainer)
    }
}
