//
//  DatePickerView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 10.08.26.
//


import SwiftUI

struct DatePickerView: View {
    //MARK:- PROPERTIES
    @EnvironmentObject var logic: TimerLogic

    
    //MARK:- BODY
    var body: some View {
        VStack(alignment: .center, spacing: 10, content: {
            DatePicker("Pick a Date",
                       selection: logic.$endDate, in: Date()...,
                       displayedComponents: [.date]
            )
                .datePickerStyle(.compact)
        })
    }
}

//MARK:- PREVIEW
struct TimePickerView_Previews: PreviewProvider {
    static var previews: some View {
        DatePickerView()
            .previewLayout(.sizeThatFits)
            .padding()
            .environmentObject(TimerLogic())
    }
}