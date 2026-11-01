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
            Section {
                Toggle("Pick when the dough comes out of the fridge", isOn: outModeBinding)
                if recipeSetupData.fridgeTimeMode == "OUT" {
                    DatePicker("Out of the fridge", selection: $recipeSetupData.fridgeOutSelection,
                               in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    LabeledContent("Fridge Time", value: "\(Int(recipeSetupData.effectiveCoolTime().rounded())) h")
                    LabeledContent("Serving") {
                        Text(recipeSetupData.fridgeOutSelection.addingTimeInterval(recipeSetupData.roomTime * 3600),
                             format: .dateTime.weekday().day().month().hour().minute())
                    }
                }
            } footer: {
                Text("The fridge time is calculated from now until this moment; serving = out of the fridge + room time.")
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

    private var outModeBinding: Binding<Bool> {
        Binding {
            recipeSetupData.fridgeTimeMode == "OUT"
        } set: { isOn in
            if isOn {
                if recipeSetupData.fridgeOutSelection < Date() {
                    recipeSetupData.fridgeOutSelection = Date().addingTimeInterval(24 * 3600)
                }
                recipeSetupData.fridgeTimeMode = "OUT"
            } else {
                recipeSetupData.fridgeTimeMode = "MAN"
            }
        }
    }
}

#Preview {
    let recipeSetupData = RecipeSetupData(doughBallsCount: 4, doughWeight: 300, waterRatio: 65, saltRatio: 3, yeastSelection: 1, fridgeTimeMode: "MANUAL", roomTemp: 27, roomTime: 12, coolTemp: 4, coolTime: 12, dateSelection: Date())
    let path = Binding.constant(NavigationPath())
    FermentRoomTimeTempView(recipeSetupData: recipeSetupData, path: path, isShowingNewRecipeView: .constant(false))
        .padding(.horizontal)
}
