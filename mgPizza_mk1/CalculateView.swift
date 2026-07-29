//
//  CalculateView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftUI

struct CalculateView: View {
    @State private var doughWeight: Double = 250.0
    @State private var waterRatio: Double = 65.0
    @State private var saltRatio: Double = 3.0
    @State private var yeastSelection = 0
    
    @State private var roomTemp: Double = 20.0
    @State private var roomTime: Double = 4.0
    @State private var coolTemp: Double = 4.0
    @State private var coolTime: Double = 12.0
    
    var yeastTypes = ["Fresh Yeast", "Dry Yeast", "Instant Dry Yeast"]
    
    var flour: Double {
        let totalFactor = 1.0 + (waterRatio / 100.0) + (saltRatio / 100.0)
        return doughWeight / totalFactor
    }
    
    var water: Double {
        return flour * (waterRatio / 100.0)
    }
    
    var salt: Double {
        return flour * (saltRatio / 100.0)
    }
    
    var yeast: Double {
        let baseConstant = 27.42  //27.42
        let activityRoom = pow(1.304, roomTemp - 10.0)
        let activityCool = 1.465 * pow(1.146, coolTemp - 1.0)
        let total = (roomTime * activityRoom) + (coolTime * activityCool)
        
        guard total > 0 else { return 0.0 }
        return (baseConstant * (flour / 100.0)) / total
    }

    var body: some View {
        NavigationStack {
            Form {
                // --- CALCULATED RECIPE ---
                Section(header: Text("Ingredients")) {
                    HStack {
                        Text("Flour")
                        Spacer()
                        Text("\(flour, specifier: "%.1f") g").bold()
                    }
                    HStack {
                        Text("Water")
                        Spacer()
                        Text("\(water, specifier: "%.1f") g").bold()
                    }
                    HStack {
                        Text("Salt")
                        Spacer()
                        Text("\(salt, specifier: "%.2f") g").bold()
                    }
                    HStack {
                        Text("Yeast")
                        Spacer()
                        Text("\(yeast, specifier: "%.2f") g").bold().foregroundColor(.orange)
                    }
                    HStack {
                        VStack {
                            Picker("Yeast Type", selection: $yeastSelection) {
                                Text("FY").tag(0)
                                Text("DY").tag(1)
                                Text("IDY").tag(2)
                            }
                            .pickerStyle(.segmented)
                            Text("\(yeastTypes[yeastSelection])")
                        }
                    }
                }
                
                // --- INPUTS DOUGH ---
                Section(header: Text("Dough-Settings")) {
                    VStack(alignment: .leading) {
                        Text("Dough Weight: \(Int(doughWeight)) g")
                        Slider(value: $doughWeight, in: 100...2000, step: 10)
                    }
                    VStack(alignment: .leading) {
                        Text("Water: \(Int(waterRatio)) %")
                        Slider(value: $waterRatio, in: 50...90, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Salt: \(saltRatio, specifier: "%.1f") %")
                        Slider(value: $saltRatio, in: 1.0...4.0, step: 0.1)
                    }
                }
                
                // --- INPUTS FERMENT ---
                Section(header: Text("Ferment Time & Temperature")) {
                    Stepper("Room Time: \(Int(roomTime)) h", value: $roomTime, in: 0...48)
                    Stepper("Room Temperature: \(Int(roomTemp)) °C", value: $roomTemp, in: 10...30)
                    
                    Stepper("Cool Time: \(Int(coolTime)) h", value: $coolTime, in: 0...72)
                    Stepper("Cool Temperature: \(Int(coolTemp)) °C", value: $coolTemp, in: 1...10)
                }
            }
            .navigationTitle("Dough Calculater")
        }
    }
}

#Preview {
    CalculateView()
}
