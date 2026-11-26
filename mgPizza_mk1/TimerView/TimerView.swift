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
    @State var dateEnd: Date
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 20) {
                DigitView(time: logic.days, place: places[0])
                DigitView(time: logic.hours, place: places[1])
                DigitView(time: logic.minutes, place: places[2])
                DigitView(time: logic.seconds, place: places[3])
                
            }.onReceive(logic.timer, perform: { _ in
                let timer = Timer(timeInterval: 1, repeats: true) { Timer in
                    logic.currentDate = Date()
                    let (d,h,m,s) = logic.getTime(from: logic.currentDate, untill: dateEnd)
                    logic.days = d
                    logic.hours = h
                    logic.minutes = m
                    logic.seconds = s
                }
                
                if logic.currentDate >= dateEnd {
                    logic.isTimerRunning = false
                    getTimerNotification()
                } else {
                    logic.isTimerRunning = true
                }
                
                logic.isTimerRunning ? timer.fire() : timer.invalidate()
            })
        }
    }
    
    func getTimerNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Timer expired"
        content.body = "Time is up!"
        content.sound = .default
        
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: sekunden, repeats: false)
        let request = UNNotificationRequest(identifier: "MyTimerID", content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error during creation: \(error.localizedDescription)")
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                didReceive response: UNNotificationResponse,
                withCompletionHandler completionHandler:
                   @escaping () -> Void) {
       // Aktuell keine eigenen Notification-Aktionen – nur abschließen.
       // Always call the completion handler when done.
       completionHandler()
    }
}

#Preview {
    let dateEnd: Date = Date(timeIntervalSince1970: TimeInterval(1786515330))
    TimerView(dateEnd: dateEnd)
        .environmentObject(TimerLogic())
}

//struct TimerView_Previews: PreviewProvider {
//    var dateEnd: Date
//    static var previews: some View {
//        TimerView(dateEnd: dateEnd)
//            .previewLayout(.sizeThatFits)
//            .padding()
//            .environmentObject(TimerLogic())
//    }
//}
