//
//  AppRouter.swift
//  mgPizza_mk1
//

import Combine
import SwiftUI
import UIKit

/// Navigation von überall aus, z. B. nach START im Rezept-Setup direkt ins Rezept wechseln
/// oder über die Schnellaktionen am App-Symbol (lange drücken).
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: MainTab = .activity
    @Published var openRecipe: RecipeSetupData?
    /// Sheet „Neues Rezept“ öffnen
    @Published var showNewRecipe = false
    /// Diesen Anlass im Tab „Anlass“ öffnen
    @Published var openEventID: String?
    /// Geteilte Ansicht (Zubereitung) des aktuellen Anlasses öffnen
    @Published var showFoldView = false

    func open(_ recipe: RecipeSetupData) {
        // Kurz warten, bis das Setup-Sheet geschlossen ist
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.selectedTab = .activity
            self.openRecipe = recipe
        }
    }

    // MARK: Schnellaktionen am App-Symbol

    enum Shortcut: String {
        case newDough = "de.mgpizza.newDough"
        case currentEvent = "de.mgpizza.currentEvent"
        case splitView = "de.mgpizza.splitView"
        case shopping = "de.mgpizza.shopping"
    }

    /// Schnellaktionen setzen (der aktuelle Anlass steht mit Namen drin)
    static func updateShortcuts() {
        let defaults = UserDefaults.standard
        let eventID = defaults.string(forKey: AppKeys.menuEventID) ?? ""
        let title = defaults.string(forKey: AppKeys.menuTitle) ?? ""
        var items = [
            UIApplicationShortcutItem(type: Shortcut.newDough.rawValue, localizedTitle: String(localized: "New dough"),
                                      localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "plus.circle"), userInfo: nil),
            UIApplicationShortcutItem(type: Shortcut.shopping.rawValue, localizedTitle: String(localized: "Shopping list"),
                                      localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "cart"), userInfo: nil),
        ]
        if !eventID.isEmpty {
            let subtitle = title.isEmpty ? nil : title
            items.insert(UIApplicationShortcutItem(type: Shortcut.splitView.rawValue, localizedTitle: String(localized: "Split view"),
                                                   localizedSubtitle: subtitle,
                                                   icon: UIApplicationShortcutIcon(systemImageName: "rectangle.split.1x2"), userInfo: nil), at: 0)
            items.insert(UIApplicationShortcutItem(type: Shortcut.currentEvent.rawValue, localizedTitle: String(localized: "Orders"),
                                                   localizedSubtitle: subtitle,
                                                   icon: UIApplicationShortcutIcon(systemImageName: "party.popper"), userInfo: nil), at: 0)
        }
        UIApplication.shared.shortcutItems = items
    }

    /// Schnellaktion ausführen; false, wenn unbekannt
    @discardableResult
    func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard let shortcut = Shortcut(rawValue: item.type) else { return false }
        // Kurz warten, damit die Oberfläche nach dem Start steht
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch shortcut {
            case .newDough:
                self.selectedTab = .recipes
                self.showNewRecipe = true
            case .currentEvent:
                self.selectedTab = .events
                self.openEventID = UserDefaults.standard.string(forKey: AppKeys.menuEventID)
            case .splitView:
                self.showFoldView = true
            case .shopping:
                self.selectedTab = .shopping
            }
        }
        return true
    }
}

/// Nimmt die Schnellaktionen entgegen (beim Kaltstart und wenn die App schon läuft)
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem { AppRouter.shared.handle(item) }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(AppRouter.shared.handle(shortcutItem))
    }
}
