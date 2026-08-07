//
//  MainView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftUI

struct MainView: View {
    @State private var isShowingNewRecipeView: Bool = false
    
    var body: some View {
        NavigationStack {
            TabView {
                ActivityView()
                    .tabItem {
                        Label("Activity", systemImage: "house")
                    }
//                CalculateView()
//                    .tabItem {
//                        Label("Calculator", systemImage: "pizza")
//                    }
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Actions", systemImage: "ellipsis") {
                        Button("New Recipe", systemImage: "square.and.pencil") {
                            isShowingNewRecipeView.toggle()
                        }
                        Button("Open Recipe", systemImage: "folder") {
                            print("New")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingNewRecipeView) {
                RecipeContainerView()
            }
        }
    }
}

#Preview {
    MainView()
}
