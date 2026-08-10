//
//  FermentRoomTimeTempView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import SwiftUI

struct FermentRoomTimeTempView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var recipeSetupData: RecipeSetupData
    @Binding var path: NavigationPath
    @Binding var isShowingNewRecipeView: Bool
    
    var body: some View {
        Form {
            Section("Step 2 of 3") {
                Stepper("Room Time: \(Int(recipeSetupData.roomTime)) h", value: $recipeSetupData.roomTime, in: 0...48)
                Stepper("Room Temperature: \(Int(recipeSetupData.roomTemp)) °C", value: $recipeSetupData.roomTemp, in: 10...30)
            }
        }
        .navigationTitle("Ferment Room Time & Temp").font(.subheadline)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel", systemImage: "xmark") {
                    isShowingNewRecipeView = false
                }
            }
        }
        
        Button("Continue") {
            path.append(RecipeSetupStep.fermentFridgeTimeTemp)
        }
    }
}

#Preview {
    let recipeSetupData = RecipeSetupData(doughBallsCount: 4, doughWeight: 300, waterRatio: 65, saltRatio: 3, yeastSelection: 1, fridgeTimeMode: "MANUAL", roomTemp: 27, roomTime: 12, coolTemp: 4, coolTime: 12, dateSelection: Date())
    let path = Binding.constant(NavigationPath())
    FermentRoomTimeTempView(recipeSetupData: recipeSetupData, path: path, isShowingNewRecipeView: .constant(false))
        .padding(.horizontal)
}
