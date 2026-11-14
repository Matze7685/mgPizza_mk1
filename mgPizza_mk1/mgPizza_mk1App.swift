//
//  mgPizza_mk1App.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 28.07.26.
//

import SwiftData
import SwiftUI
import UserNotifications

/// Zeigt Benachrichtigungen auch an, wenn die App gerade offen ist (z. B. Knet-Timer).
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        _ = OvenMonitor.shared   // Bluetooth sofort wiederherstellen, auch wenn iOS die App im Hintergrund startet
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(TimerLogic())
                .environmentObject(ovenMonitor)
        }
//        .modelContainer(for: RecipeSetupData.self)
        .modelContainer(sharedModelContainer)
    }
}
