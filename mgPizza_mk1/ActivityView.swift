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
    
    @State private var selectedRecipe: RecipeSetupData?
    
    @State private var showSetup: Bool = false
    @State private var showDetail: Bool = false
    
    @State var count = 0
    
    var body: some View {
        VStack {
            Section(header: Text("Timer").font(.largeTitle)) {
                List {
                    ForEach(recipeSetupData) { data in
                        Button {
                            
                        } label: {
                            HStack {
                                TimerView(dateEnd: data.dateSelection)
                                    .environmentObject(TimerLogic())
                                Spacer()
                                Divider()
                                VStack {
                                    Text("\(data.dateSelection, format: .dateTime.weekday().day().month() )")
                                        .font(.caption)
                                    Text(data.dateSelection, format: .dateTime.hour().minute())
                                        .font(.title)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteRecipe)
                }
                .sheet(item: $selectedRecipe) { recipe in
                    RecipeDetailView(recipeData: recipe)
                }
            }
            Spacer()
        }
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
