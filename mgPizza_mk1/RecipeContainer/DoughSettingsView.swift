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
                Picker("Style", selection: $recipeSetupData.style) {
                    Text("Round").tag("round")
                    Text("Detroit").tag("detroit")
                }
                .pickerStyle(.segmented)
                if recipeSetupData.isDetroit {
                    Stepper("Pans: \(Int(recipeSetupData.doughBallsCount))", value: $recipeSetupData.doughBallsCount, in: 1...20)
                    VStack(alignment: .leading) {
                        Text("Pan Width: \(Int(recipeSetupData.panWidth)) cm")
                        Slider(value: $recipeSetupData.panWidth, in: 10...50, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Pan Length: \(Int(recipeSetupData.panLength)) cm")
                        Slider(value: $recipeSetupData.panLength, in: 10...60, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Dough Thickness: \(recipeSetupData.doughThickness, specifier: "%.1f") mm")
                        Slider(value: $recipeSetupData.doughThickness, in: 3...10, step: 0.5)
                        Text("Raw dough pressed into the pan. ~5–6 mm = classic, rises to ~2.5–3 cm.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    LabeledContent("Dough per Pan", value: "\(Int(recipeSetupData.doughWeight)) g")
                } else {
                    Stepper("Dough Balls: \(Int(recipeSetupData.doughBallsCount))", value: $recipeSetupData.doughBallsCount, in: 1...60)
                    VStack(alignment: .leading) {
                        Text("Dough Weight: \(Int(recipeSetupData.doughWeight)) g")
                        Slider(value: $recipeSetupData.doughWeight, in: 100...2000, step: 10)
                    }
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
        .onChange(of: recipeSetupData.style) { _, newStyle in
            if newStyle == "detroit" {
                // Typische Detroit-Werte: hohe Hydration, etwas Öl
                recipeSetupData.waterRatio = 72
                recipeSetupData.saltRatio = 2.5
                recipeSetupData.oilRatio = 2
                recipeSetupData.doughBallsCount = 1
                recipeSetupData.applyDetroitWeight()
            } else {
                recipeSetupData.waterRatio = 65
                recipeSetupData.saltRatio = 3
                recipeSetupData.oilRatio = 0
                recipeSetupData.doughWeight = 250
            }
        }
        .onChange(of: recipeSetupData.panWidth) { recipeSetupData.applyDetroitWeight() }
        .onChange(of: recipeSetupData.panLength) { recipeSetupData.applyDetroitWeight() }
        .onChange(of: recipeSetupData.doughThickness) { recipeSetupData.applyDetroitWeight() }
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
