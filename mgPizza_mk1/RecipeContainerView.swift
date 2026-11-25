//
//  RecipeSetupView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import SwiftData
import SwiftUI

/// Neues Rezept / Vorlage: alles auf einer Seite (Teig, Hefe, Zeitplan, Ergebnis).
struct RecipeContainerView: View {
    @State private var recipeSetupData: RecipeSetupData
    @Binding var isShowingNewRecipeView: Bool

    init(recipeSetupData: RecipeSetupData, isShowingNewRecipeView: Binding<Bool>) {
        self.recipeSetupData = recipeSetupData
        self._isShowingNewRecipeView = isShowingNewRecipeView
    }

    var body: some View {
        NavigationStack {
            DoughSettingsView(recipeSetupData: recipeSetupData, isShowingNewRecipeView: $isShowingNewRecipeView)
        }
    }
}
