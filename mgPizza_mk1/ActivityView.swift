//
//  ActivityView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftData
import SwiftUI

struct ActivityView: View {
    @Query private var recipeSetupData: [RecipeSetupData]
    
    var body: some View {
        Text("ActivityView")
    }
}

#Preview {
    ActivityView()
}
