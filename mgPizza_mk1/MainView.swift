//
//  MainView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 28.07.26.
//

import SwiftUI
import UIKit

struct MainView: View {
    @State private var doughBallsCount: Int = 1
    @State private var doughBallsWeight: Int = 100
    @State private var waterRatio: Int = 100
    @State private var saltRatio: Double = 3
    @State private var proofingTimeIndoor: Int = 1
    @State private var proofingTimeFridge: Int = 1
    @State private var temperatureIndoor: Int = 26
    @State private var temperatureFridge: Int = 26
    @State private var flourWeight: Int = 1
    @State private var waterWeight: Int = 1
    @State private var saltWeight: Int = 1
    @State private var yeastWeight: Int = 1
    
//    @State private var yeastType: Yeast =
    
    var body: some View {
        VStack {
            doughBallsCountView
            doughBallsWeightView
            waterView
            saltView
            Spacer()
            totalView
        }
        .padding(10)
    }
    
    var doughBallsCountView: some View {
        VStack {
            HStack {
                CustomStepperView(value: $doughBallsCount, stepValue: 1, minimumValue: 1, maximumValue: 100)
                Text("Dough Balls Count: \(doughBallsCount)")
                Spacer()
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
    }
    var doughBallsWeightView: some View {
        VStack {
            HStack {
                CustomStepperView(value: $doughBallsWeight, stepValue: 5, minimumValue: 5, maximumValue: 1000)
                Text("Dough Balls Weight: \(doughBallsWeight)")
                Spacer()
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
    }
    var waterView: some View {
        VStack {
            HStack {
                CustomStepperView(value: $waterRatio, stepValue: 1, minimumValue: 40, maximumValue: 100)
                Text("Water Ratio: \(waterRatio)%")
                Spacer()
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
    }
    var saltView: some View {
        VStack {
            HStack {
                CustomStepperView(value: $saltRatio, stepValue: Int(0.1), minimumValue: 0, maximumValue: 5)
                Text("Salt Ratio: \(saltRatio)%")
                Spacer()
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
    }
    
    
    var totalView: some View {
        VStack {
            Text("Total Dough Weight: \(doughBallsCount * doughBallsWeight)")
            HStack {
                Text("Flour: \((doughBallsCount * doughBallsWeight) / 2 /*flourWeight*/)g")
                Text("Water: \((doughBallsCount * doughBallsWeight) / 2)g")
            }
            HStack {
                Text("Salt: \(saltWeight)g")
                Text("Yeast: \(yeastWeight)g")
            }
        }
    }
    
    func calculateYeastWeight(flour: Double, roomTemp: Double, roomTime: Double, fridgeTemp: Double, fridgeTime: Double) -> Double {
        let baseConstant = 27.42
        let roomActivity = pow(1.304, roomTemp - 10.0)
        let fridgeActivity = 1.465 * pow(1.146, fridgeTemp - 1.0)
        let fermentationTime = (roomTime * roomActivity) + (fridgeTime * fridgeActivity)
        guard fermentationTime > 0 else { return 0 }
        return baseConstant * (flour / 100.0) / fermentationTime
//        return flour / (baseConstant + fermentationTime)
        
//        let yeast = calculateYeastWeight(flour: 1000, roomTemp: 12, roomTime: 4, fridgeTemp: 2, fridgeTime: 24)
    }
    
    func calculateFlourWeight(doughBallWeight: Double, waterRatio: Double) -> (mehl: Double, wasser: Double) {
        let flour = doughBallWeight / (1.0 + (waterRatio / 100.0))
        let water = doughBallWeight - flour
        return (flour, water)
    }
}

#Preview {
    MainView()
}


struct CustomStepperView: UIViewRepresentable {
    @Binding var value: Int
    var stepValue: Double
    var minimumValue: Double
    var maximumValue: Int
    
    func makeUIView(context: Context) -> UIStepper {
        let stepper = UIStepper()
        stepper.minimumValue = Double(minimumValue)
        stepper.maximumValue = Double(maximumValue)
        stepper.stepValue = Double(stepValue)
        stepper.value = Double(value)
        
        stepper.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        
        return stepper
    }
    
    func updateUIView(_ uiView: UIStepper, context: Context) {
        uiView.value = Double(value)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: CustomStepperView
        
        init(_ parent: CustomStepperView) {
            self.parent = parent
        }
        
        @objc func valueChanged(_ sender: UIStepper) {
            parent.value = Int(sender.value)
        }
    }
}
