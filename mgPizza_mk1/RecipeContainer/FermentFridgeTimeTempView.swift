//
//  FermentFridgeTimeTemp.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import SwiftUI

struct FermentFridgeTimeTempView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var recipeSetupData: RecipeSetupData
    @Binding var path: NavigationPath
    
    var body: some View {
        Form {
            Section("Step 3 of 3") {
                Stepper("Cool Temperature: \(Int(recipeSetupData.coolTemp)) °C", value: $recipeSetupData.coolTemp, in: 1...10)
            }
            Section("") {
                Picker("Fridge Time Mode", selection: $recipeSetupData.fridgeTimeMode) {
                    Text("AUTO").tag("AUTO")
                    Text("MANUAL").tag("MAN")
                }
                .pickerStyle(.segmented)
                if recipeSetupData.fridgeTimeMode == "AUTO" {
                    fridgeTimeAuto
                } else {
                    fridgeTimeManual
                }
            }
        }
        .navigationTitle("Ferment Fridge Time & Temp").font(.subheadline)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel", systemImage: "xmark") {
                    dismiss()
                }
            }
        }
        
        Button("Continue") {
            path.append(RecipeSetupStep.doughResult)
        }
    }
    
    var fridgeTimeAuto: some View {
        HStack {
            Spacer()
            FridgeTimeDatePicker(selectedDate: $recipeSetupData.dateSelection)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
            Spacer()
        }
    }
    var fridgeTimeManual: some View {
        Stepper("Cool Time: \(Int(recipeSetupData.coolTime)) h", value: $recipeSetupData.coolTime, in: 0...72)
    }
}

#Preview {
    let recipeSetupData = RecipeSetupData(doughBallsCount: 4, doughWeight: 300, waterRatio: 65, saltRatio: 3, yeastSelection: 1, fridgeTimeMode: "MANUAL", roomTemp: 27, roomTime: 12, coolTemp: 4, coolTime: 12, dateSelection: Date())
    let path = Binding.constant(NavigationPath())
    FermentFridgeTimeTempView(recipeSetupData: recipeSetupData, path: path)
        .padding(.horizontal)
}
