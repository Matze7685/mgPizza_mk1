//
//  RecipeSetupView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import Combine
import SwiftData
import SwiftUI

struct RecipeContainerView: View {
    @Environment(\.modelContext) var modelContext
    
    @State private var recipeSetupData: RecipeSetupData
    @State private var path = NavigationPath()
    @Binding var isShowingNewRecipeView: Bool
    
    init(recipeSetupData: RecipeSetupData, isShowingNewRecipeView: Binding<Bool>) {
        self.recipeSetupData = recipeSetupData
        self._isShowingNewRecipeView = isShowingNewRecipeView
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            DoughSettingsView(recipeSetupData: recipeSetupData, path: $path, isShowingNewRecipeView: $isShowingNewRecipeView)
                .navigationDestination(for: RecipeSetupStep.self) { step in
                    switch step {
                    case .fermentRoomTimeTemp:
                        FermentRoomTimeTempView(recipeSetupData: recipeSetupData, path: $path, isShowingNewRecipeView: $isShowingNewRecipeView)
                    case .fermentFridgeTimeTemp:
                        FermentFridgeTimeTempView(recipeSetupData: recipeSetupData, path: $path, isShowingNewRecipeView: $isShowingNewRecipeView)
                    case .doughResult:
                        DoughResultView(recipeSetupData: recipeSetupData, path: $path, isShowingNewRecipeView: $isShowingNewRecipeView)
                    }
                }
        }
    }
}

#Preview {
//    RecipeContainerView()
}
