//
//  AppRouter.swift
//  mgPizza_mk1
//

import Combine
import SwiftUI

/// Navigation von überall aus, z. B. nach START im Rezept-Setup direkt ins Rezept wechseln.
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: MainTab = .activity
    @Published var openRecipe: RecipeSetupData?

    func open(_ recipe: RecipeSetupData) {
        // Kurz warten, bis das Setup-Sheet geschlossen ist
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.selectedTab = .activity
            self.openRecipe = recipe
        }
    }
}
