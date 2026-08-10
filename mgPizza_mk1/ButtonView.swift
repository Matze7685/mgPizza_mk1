//
//  ButtonView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 10.08.26.
//


import SwiftUI

struct ButtonView: View {
    //MARK:- PROPERTIES
    @EnvironmentObject var logic: TimerLogic
    
    //MARK:- BODY
    var body: some View {
        
        HStack(alignment:.center, spacing: 5) {
            Button(action: {
                logic.isTimerRunning.toggle()
            }
            , label: {
                Spacer()
                Image(systemName: logic.isTimerRunning ? "pause.circle" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                Text(logic.isTimerRunning ? "Pause" : "Resume")
                    .font(.system(.title2, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            })//: BUTTON
            .padding(15)
            .background(logic.isTimerRunning ? Color(.systemOrange) : Color(.systemGreen))
            .clipShape(Capsule())
            
        }//: HSTACK
    }
}

//MARK:- PREVIEW
struct ResetView_Previews: PreviewProvider {
    static var previews: some View {
        ButtonView()
            .previewLayout(.sizeThatFits)
            .padding()
            .environmentObject(TimerLogic())
    }
}