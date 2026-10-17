//
//  DoughSettingsView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import SwiftUI

struct DoughSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var recipeSetupData: RecipeSetupData
    @Binding var path: NavigationPath
    @Binding var isShowingNewRecipeView: Bool
    
    var body: some View {
        Form {
            Section("Step 1 of 3") {
                TextField("Name (e.g. Neapolitan)", text: $recipeSetupData.name)
                Stepper("Dough Balls: \(Int(recipeSetupData.doughBallsCount))", value: $recipeSetupData.doughBallsCount, in: 1...60)
                VStack(alignment: .leading) {
                    Text("Dough Weight: \(Int(recipeSetupData.doughWeight)) g")
                    Slider(value: $recipeSetupData.doughWeight, in: 100...2000, step: 10)
                }
                VStack(alignment: .leading) {
                    Text("Water: \(Int(recipeSetupData.waterRatio)) %")
                    Slider(value: $recipeSetupData.waterRatio, in: 50...90, step: 1)
                }
                VStack(alignment: .leading) {
                    Text("Salt: \(recipeSetupData.saltRatio, specifier: "%.1f") %")
                    Slider(value: $recipeSetupData.saltRatio, in: 1.0...4.0, step: 0.1)
                }
            }
            Section(header: Text("Optional"), footer: Text("Oil and sugar help browning in home ovens / gas grills below ~400 °C. Leave at 0 for Neapolitan style.")) {
                VStack(alignment: .leading) {
                    Text("Olive Oil: \(recipeSetupData.oilRatio, specifier: "%.1f") %")
                    Slider(value: $recipeSetupData.oilRatio, in: 0...5, step: 0.5)
                }
                VStack(alignment: .leading) {
                    Text("Sugar: \(recipeSetupData.sugarRatio, specifier: "%.1f") %")
                    Slider(value: $recipeSetupData.sugarRatio, in: 0...3, step: 0.5)
                }
            }
            Section("Yeast") {
                HStack {
                    VStack {
                        Picker("Yeast Type", selection: $recipeSetupData.yeastSelection) {
                            Text("Fresh").tag(0)
                            Text("Dry").tag(1)
                            Text("Instant Dry").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Yeast Correction: \(Int(recipeSetupData.yeastCorrection)) %")
                    Slider(value: $recipeSetupData.yeastCorrection, in: 25...200, step: 5)
                    Text("Lower it if your dough over-proofs, raise it if it stays too flat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Dough Settings").font(.subheadline)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel", systemImage: "xmark") {
                    isShowingNewRecipeView = false
                }
            }
        }
        
        Button("Continue") {
            path.append(RecipeSetupStep.fermentRoomTimeTemp)
        }
    }
}

#Preview {
    let recipeSetupData = RecipeSetupData(doughBallsCount: 4, doughWeight: 300, waterRatio: 65, saltRatio: 3, yeastSelection: 1, fridgeTimeMode: "MANUAL", roomTemp: 27, roomTime: 12, coolTemp: 4, coolTime: 12, dateSelection: Date())
    let path = Binding.constant(NavigationPath())
    DoughSettingsView(recipeSetupData: recipeSetupData, path: path, isShowingNewRecipeView: .constant(false))
        .padding(.horizontal)
}
