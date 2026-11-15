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
                if !isDateMode {
                    Stepper("Room Time: \(Int(recipeSetupData.roomTime)) h", value: $recipeSetupData.roomTime, in: 0...48)
                }
                Stepper("Room Temperature: \(Int(recipeSetupData.roomTemp)) °C", value: $recipeSetupData.roomTemp, in: 10...30)
            }
            Section {
                Toggle("Set times by date", isOn: outModeBinding)
                if isDateMode {
                    DatePicker("Out of the fridge", selection: $recipeSetupData.fridgeOutSelection,
                               in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Serving", selection: $recipeSetupData.dateSelection,
                               in: recipeSetupData.fridgeOutSelection..., displayedComponents: [.date, .hourAndMinute])
                    LabeledContent("Fridge Time", value: hours(recipeSetupData.effectiveCoolTime()))
                    LabeledContent("Room Time", value: hours(recipeSetupData.roomTime))
                }
            } footer: {
                Text("Fridge time = now until out of the fridge. Room time = out of the fridge until serving. Both are calculated for you.")
            }
        }
        .onChange(of: recipeSetupData.fridgeOutSelection) { updateRoomTime() }
        .onChange(of: recipeSetupData.dateSelection) { updateRoomTime() }
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

    private var isDateMode: Bool { recipeSetupData.fridgeTimeMode == "OUT" }

    /// Raumzeit = aus dem Kühlschrank bis Servieren
    private func updateRoomTime() {
        guard isDateMode else { return }
        if recipeSetupData.dateSelection < recipeSetupData.fridgeOutSelection {
            recipeSetupData.dateSelection = recipeSetupData.fridgeOutSelection
        }
        recipeSetupData.roomTime = max(0, recipeSetupData.dateSelection.timeIntervalSince(recipeSetupData.fridgeOutSelection) / 3600)
    }

    private func hours(_ value: Double) -> String {
        let total = Int((value * 60).rounded())
        return total % 60 == 0 ? "\(total / 60) h" : String(format: "%d h %02d min", total / 60, total % 60)
    }

    private var outModeBinding: Binding<Bool> {
        Binding {
            recipeSetupData.fridgeTimeMode == "OUT"
        } set: { isOn in
            if isOn {
                if recipeSetupData.fridgeOutSelection < Date() {
                    recipeSetupData.fridgeOutSelection = Date().addingTimeInterval(24 * 3600)
                }
                // Vorschlag: Servieren = raus + bisherige Raumzeit
                recipeSetupData.dateSelection = recipeSetupData.fridgeOutSelection.addingTimeInterval(recipeSetupData.roomTime * 3600)
                recipeSetupData.fridgeTimeMode = "OUT"
                updateRoomTime()
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
