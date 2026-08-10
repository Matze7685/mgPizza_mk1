//
//  TimerLogic.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 10.08.26.
//

import Combine
import SwiftUI

class TimerLogic: ObservableObject {
    
    @Published var currentDate = Date()
    @Published var days: Int = 0
    @Published var hours: Int = 0
    @Published var minutes: Int = 0
    @Published var seconds: Int = 0
    var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @AppStorage("isTimerRunning") var isTimerRunning: Bool = false
    @AppStorage("endDate") var endDate = Date()

    
    func getTime(from date: Date, untill nowDate: Date) -> (Int, Int, Int, Int) {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.day, .hour, .minute, .second], from: date, to: nowDate)
        
        return (
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }
}
