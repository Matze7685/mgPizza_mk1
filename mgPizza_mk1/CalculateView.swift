//
//  CalculateView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftUI

struct CalculateView: View {
    @State private var doughBallsCount: Double = 1.0
    @State private var doughWeight: Double = 250.0
    @State private var waterRatio: Double = 65.0
    @State private var saltRatio: Double = 3.0
    @State private var yeastSelection: Int = 0
    @State private var fridgeTimeMode: String = "AUTO"
    @State private var dateSelection: Date = Date()
    
    @State private var roomTemp: Double = 20.0
    @State private var roomTime: Double = 4.0
    @State private var coolTemp: Double = 4.0
    @State private var coolTime: Double = 12.0
    
//    var yeastTypes = ["Fresh Yeast", "Dry Yeast", "Instant Dry Yeast"]
    var yeastTypes = ["Frische Hefe", "Trockenhefe", "Instant Trockenhefe"]
    var yeastRatio = [3.0, 1.5, 1.0]
    
    var flour: Double {
        let totalFactor = 1.0 + (waterRatio / 100.0) + (saltRatio / 100.0)
        return doughWeight / totalFactor * doughBallsCount
    }
    
    var water: Double {
        return flour * (waterRatio / 100.0)
    }
    
    var salt: Double {
        return flour * (saltRatio / 100.0)
    }
    
    var yeast: Double {
        let baseConstant = 27.42  //27.42
        let activityRoom = pow(1.304, roomTemp - 10.0)  //1.304
        let activityCool = 1.465 * pow(1.146, coolTemp - 1.0)   // 1.465
        let total = (roomTime * activityRoom) + (coolTime * activityCool)
        
        guard total > 0 else { return 0.0 }
        return ((baseConstant * (flour / 100.0)) / total) * yeastRatio[yeastSelection]
    }

    var body: some View {
        NavigationStack {
            Form {
                // --- CALCULATED RECIPE ---
                Section(header: Text("Ingredients")) {
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
                    Stepper("Dough Balls: \(Int(doughBallsCount))", value: $doughBallsCount, in: 1...60)
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
                Section(header: Text("Ferment Room Time & Temperature")) {
                    Stepper("Room Time: \(Int(roomTime)) h", value: $roomTime, in: 0...48)
                    Stepper("Room Temperature: \(Int(roomTemp)) °C", value: $roomTemp, in: 10...30)
                }
                
                Section(header: Text("Ferment Fridge Time & Temperature")) {
                    Picker("Fridge Time Mode", selection: $fridgeTimeMode) {
                        Text("AUTO").tag("AUTO")
                        Text("MANUAL").tag("MAN")
                    }
                    .pickerStyle(.segmented)
                    Stepper("Cool Time: \(Int(coolTime)) h", value: $coolTime, in: 0...72)
                        .disabled(fridgeTimeMode == "AUTO" ? true : false)
                        .foregroundStyle(fridgeTimeMode == "AUTO" ? Color.gray : Color.black)
                    Stepper("Cool Temperature: \(Int(coolTemp)) °C", value: $coolTemp, in: 1...10)
                        .disabled(fridgeTimeMode == "AUTO" ? true : false)
                        .foregroundStyle(fridgeTimeMode == "AUTO" ? Color.gray : Color.black)
                    
                    HStack {
                        Text("Mealtime \(dateSelection)")
                        Spacer()
                        FridgeTimeDatePicker(selectedDate: $dateSelection)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // --- START COUNTER ---
                Button{
                    
                } label: {
                    HStack {
                        Spacer()
                        Text("START")
                            .foregroundStyle(Color.green)
                            .bold()
                        Spacer()
                    }
                }
            }
            .navigationTitle("Dough Calculater")
        }
    }
}

#Preview {
    CalculateView()
}


struct FridgeTimeDatePicker: UIViewRepresentable {
    @Binding var selectedDate: Date
    
    func makeUIView(context: Context) -> UIDatePicker {
        let datePicker = UIDatePicker()
        datePicker.minuteInterval = 30
        datePicker.roundsToMinuteInterval = true
        
        var diff: Int
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: Date.now)
        if minute >= 30 {
            diff = 60 - minute
        } else {
            diff = 30 - minute
        }
        datePicker.minimumDate = Date.now.addingTimeInterval(TimeInterval(diff * 60))
        
        datePicker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.dateChanged(_:)),
            for: .valueChanged
        )
        return datePicker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.date = selectedDate
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        var parent: FridgeTimeDatePicker
        
        init(parent: FridgeTimeDatePicker) {
            self.parent = parent
        }
        @objc func dateChanged(_ sender: UIDatePicker) {
            parent.selectedDate = sender.date
        }
    }
}
