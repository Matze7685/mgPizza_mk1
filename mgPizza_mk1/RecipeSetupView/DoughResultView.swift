//
//  DoughResultView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import SwiftUI

struct DoughResultView: View {
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
        .navigationTitle("Result").font(.subheadline)
        .navigationBarTitleDisplayMode(.inline)
        
        HStack {
            Button{
                
            } label: {
                HStack {
                    Spacer()
                    Text("+ ADD RECIPE")
                        .foregroundStyle(Color.black)
                        .bold()
                    Spacer()
                }
            }
            .padding()
            .background(Color.blue)
            .clipShape(.capsule)
            
            Button{
                
            } label: {
                HStack {
                    Spacer()
                    Text("START RECIPE")
                        .foregroundStyle(Color.black)
                        .bold()
                    Spacer()
                }
            }
            .padding()
            .background(Color.green)
            .clipShape(.capsule)
        }
    }
    
    func calculateFridgeHours(date1: Date, date2: Date) -> Double {
        let diffInSeconds = date2.timeIntervalSince(date1)
        let roomTime = recipeSetupData.roomTime
        return (diffInSeconds / 3600.0) - roomTime
    }
}

#Preview {
    let path = Binding.constant(NavigationPath())
    DoughResultView(recipeSetupData: RecipeSetupData(), path: path)
        .padding(.horizontal)
}
