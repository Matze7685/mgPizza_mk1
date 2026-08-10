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
    @Environment(\.modelContext) var modelContext
    @Query private var recipeSetupData: [RecipeSetupData]
    
    var body: some View {
        VStack {
            Section(header: Text("Timer").font(.largeTitle)) {
                List {
                    ForEach(recipeSetupData) { data in
                        VStack {
                            TimerView(dateEnd: data.dateSelection)
                            Text("Date: \(data.dateSelection)")
                        }
                    }
                    .onDelete(perform: deleteRecipe)
                }
            }
            Spacer()
        }
        
//        VStack {
            //TIMERVIEW
//            TimerView()
//            Spacer()
            
            //TIMEPICKERVIEW
//            DatePickerView()
//                .padding(.horizontal, 30)
            
            //BUTTONVIEW
//            ButtonView()
//                .padding(30)
//        }
    }
    
    func deleteRecipe(at offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                let dataToDelete = recipeSetupData[index]
                modelContext.delete(dataToDelete)
            }
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
