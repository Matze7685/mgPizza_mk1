//
//  DoughResultView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import SwiftData
import SwiftUI

struct DoughResultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var recipeSetupData: RecipeSetupData
    @Binding var path: NavigationPath
    
    var yeastTypes = ["Frische Hefe", "Trockenhefe", "Instant Trockenhefe"]
    var yeastRatio = [3.0, 1.5, 1.0]
    var flour: Double {
        let totalFactor = 1.0 + (recipeSetupData.waterRatio / 100.0) + (recipeSetupData.saltRatio / 100.0)
        return recipeSetupData.doughWeight / totalFactor * recipeSetupData.doughBallsCount
    }
    
    var water: Double {
        return flour * (recipeSetupData.waterRatio / 100.0)
    }
    
    var salt: Double {
        return flour * (recipeSetupData.saltRatio / 100.0)
    }
    
    var yeast: Double {
        let baseConstant = 27.42  //27.42
        let activityRoom = pow(1.304, recipeSetupData.roomTemp - 10.0)  //1.304
        let activityCool = 1.465 * pow(1.146, recipeSetupData.coolTemp - 1.0)   // 1.465
        let total = (recipeSetupData.roomTime * activityRoom) + (recipeSetupData.coolTime * activityCool)
        
        guard total > 0 else { return 0.0 }
        return ((baseConstant * (flour / 100.0)) / total) * yeastRatio[recipeSetupData.yeastSelection]
    }
    
    var body: some View {
        Form {
            ingredientsSection
            doughSection
            fermentSection
        }
        .navigationTitle("Result").font(.subheadline)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        
        saveAndStartButton
    }
    
    var ingredientsSection: some View {
        Section(header: Text("")) {
            HStack {
                Text("Flour")
                Spacer()
                Text("\(flour, specifier: "%.0f") g").bold()
            }
            HStack {
                Text("Water")
                Spacer()
                Text("\(water, specifier: "%.0f") g").bold()
            }
            HStack {
                Text("Salt")
                Spacer()
                Text("\(salt, specifier: "%.1f") g").bold()
            }
            HStack {
                Text("\(yeastTypes[recipeSetupData.yeastSelection])")
                Spacer()
                Text("\(yeast, specifier: "%.2f") g").bold().foregroundColor(.orange)
            }
        }
        .listSectionSpacing(0)
    }
    var doughSection: some View {
        Section(header: Text("")) {
            HStack {
                Text("Dough Balls")
                Spacer()
                Text("\(recipeSetupData.doughBallsCount, specifier: "%.0f")").bold()
            }
            HStack {
                Text("Dough Balls Weight")
                Spacer()
                Text("\(recipeSetupData.doughWeight, specifier: "%.0f") g").bold()
            }
        }
        .listSectionSpacing(0)
    }
    var fermentSection: some View {
        Section("") {
            HStack {
                Text("Room Time")
                Spacer()
                Text("\(recipeSetupData.roomTime, specifier: "%.0f") h").bold()
            }
            HStack {
                Text("Room Temperature")
                Spacer()
                Text("\(recipeSetupData.roomTemp, specifier: "%.0f") °C").bold()
            }
            if recipeSetupData.fridgeTimeMode == "MANUAL" {
                HStack {
                    Text("Fridge Time")
                    Spacer()
                    Text("\(recipeSetupData.coolTime, specifier: "%.0f") h").bold()
                }
            } else {
                HStack {
                    Text("Fridge Time")
                    Spacer()
                    Text("\(calculateFridgeHours(date1: Date(), date2: recipeSetupData.dateSelection), specifier: "%.0f") h").bold()
                }
            }
            HStack {
                Text("Fridge Temperature")
                Spacer()
                Text("\(recipeSetupData.coolTemp, specifier: "%.0f") °C").bold()
            }
        }
        .listSectionSpacing(0)
    }
    var saveAndStartButton: some View {
        HStack {
            Button{
                saveRecipe()
            } label: {
                HStack {
                    Spacer()
                    Text("SAVE")
                        .foregroundStyle(Color.black)
                        .bold()
                    Spacer()
                }
            }
            .padding()
            .background(Color.blue)
            .clipShape(.capsule)
            
            Button{
                saveRecipe()
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("START")
                        .foregroundStyle(Color.black)
                        .bold()
                    Spacer()
                }
            }
            .padding()
            .background(Color.green)
            .clipShape(.capsule)
        }
        .padding(.horizontal)
    }
    
    func calculateFridgeHours(date1: Date, date2: Date) -> Double {
        let diffInSeconds = date2.timeIntervalSince(date1)
        let roomTime = recipeSetupData.roomTime
        return (diffInSeconds / 3600.0) - roomTime
    }
    
    private func saveRecipe() {
        let newRecipe = RecipeSetupData(doughBallsCount: recipeSetupData.doughBallsCount, doughWeight: recipeSetupData.doughWeight, waterRatio: recipeSetupData.waterRatio, saltRatio: recipeSetupData.saltRatio, yeastSelection: recipeSetupData.yeastSelection, fridgeTimeMode: recipeSetupData.fridgeTimeMode, roomTemp: recipeSetupData.roomTemp, roomTime: recipeSetupData.roomTime, coolTemp: recipeSetupData.coolTemp, coolTime: recipeSetupData.coolTime, dateSelection: recipeSetupData.dateSelection)
        modelContext.insert(newRecipe)
    }
    
    
}

#Preview {
    let recipeSetupData = RecipeSetupData(doughBallsCount: 4, doughWeight: 300, waterRatio: 65, saltRatio: 3, yeastSelection: 1, fridgeTimeMode: "MANUAL", roomTemp: 27, roomTime: 12, coolTemp: 4, coolTime: 12, dateSelection: Date())
    let path = Binding.constant(NavigationPath())
    DoughResultView(recipeSetupData: recipeSetupData, path: path)
        .padding(.horizontal)
}
