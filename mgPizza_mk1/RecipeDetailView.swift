//
//  RecipeDetailView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 25.09.26.
//

import SwiftUI

struct RecipeDetailView: View {
    var recipeData: RecipeSetupData
    
    var body: some View {
        VStack {
            Text("Doughballs: " + String(format: "%.0f", recipeData.doughBallsCount))
            Text("Flour: ")
        }
    }
}

#Preview {
    var recipe = RecipeSetupData(doughBallsCount: 2)
    RecipeDetailView(recipeData: recipe)
}
