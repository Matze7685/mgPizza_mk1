//
//  TimerView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 10.08.26.
//

import Combine
import SwiftUI

struct TimerView: View {
    @EnvironmentObject var logic: TimerLogic
    let places: [String] = ["Days", "Hours", "Minutes", "Seconds"]
    
    @State var timeRemaining = 10
    @State private var dateNow = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            DigitView(time: logic.days, place: places[0])
            DigitView(time: logic.hours, place: places[1])
            DigitView(time: logic.minutes, place: places[2])
            DigitView(time: logic.seconds, place: places[3])
            
        }.onReceive(logic.timer, perform: { _ in
            let timer = Timer(timeInterval: 1, repeats: true) { Timer in
                logic.currentDate = Date()
                let (d,h,m,s) = logic.getTime(from: logic.currentDate, untill: logic.endDate)
                logic.days = d
                logic.hours = h
                logic.minutes = m
                logic.seconds = s
            }
            
            if logic.currentDate == logic.endDate {
                logic.isTimerRunning = false
            }
            
            logic.isTimerRunning ? timer.fire() : timer.invalidate()
        })
    }
}

//#Preview {
//    ActivityView()
//}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
            .previewLayout(.sizeThatFits)
            .padding()
            .environmentObject(TimerLogic())
    }
}
