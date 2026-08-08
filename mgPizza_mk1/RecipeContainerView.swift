//
//  RecipeSetupView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import SwiftData
import SwiftUI

struct RecipeContainerView: View {
    @Environment(\.modelContext) var modelContext
    
    @State private var recipeSetupData: RecipeSetupData
    @State private var path = NavigationPath()
    
    init(recipeSetupData: RecipeSetupData) {
        self.recipeSetupData = recipeSetupData
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            DoughSettingsView(recipeSetupData: recipeSetupData, path: $path)
                .navigationDestination(for: RecipeSetupStep.self) { step in
                    switch step {
                    case .fermentRoomTimeTemp:
                        FermentRoomTimeTempView(recipeSetupData: recipeSetupData, path: $path)
                    case .fermentFridgeTimeTemp:
                        FermentFridgeTimeTempView(recipeSetupData: recipeSetupData, path: $path)
                    case .doughResult:
                        DoughResultView(recipeSetupData: recipeSetupData, path: $path)
                    }
                }
        }
    }
}

#Preview {
//    RecipeContainerView()
}
