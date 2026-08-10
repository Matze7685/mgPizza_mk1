//
//  ActivityView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import Combine
import SwiftData
import SwiftUI

struct ActivityView: View {
    @Query private var recipeSetupData: [RecipeSetupData]
    
    var body: some View {
        VStack {
            //TIMERVIEW
            TimerView()
//            Spacer()
            
            //TIMEPICKERVIEW
            DatePickerView()
                .padding(.horizontal, 30)
            
            //BUTTONVIEW
            ButtonView()
                .padding(30)
        }
    }
}

//MARK:- PREVIEW
struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView()
            .environmentObject(TimerLogic())
    }
}
