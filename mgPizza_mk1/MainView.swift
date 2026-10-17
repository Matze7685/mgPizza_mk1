//
//  MainView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftData
import SwiftUI

enum MainTab: Hashable {
    case activity, recipes, sauce, shopping, settings
}

struct MainView: View {
    @State private var isShowingNewRecipeView: Bool = false
    @State private var selectedTab: MainTab = .activity
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ActivityView()
                    .tabItem {
                        Label("Activity", systemImage: "house")
                    }
                    .tag(MainTab.activity)
                RecipesView()
                    .tabItem {
                        Label("Dough", systemImage: "book")
                    }
                    .tag(MainTab.recipes)
                SauceListView()
                    .tabItem {
                        Label("Sauce", systemImage: "drop")
                    }
                    .tag(MainTab.sauce)
                ShoppingListView()
                    .tabItem {
                        Label("Shopping", systemImage: "cart")
                    }
                    .tag(MainTab.shopping)
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(MainTab.settings)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Actions", systemImage: "ellipsis") {
                        Button("New Recipe", systemImage: "square.and.pencil") {
                            isShowingNewRecipeView.toggle()
                        }
                        Button("Open Recipe", systemImage: "folder") {
                            selectedTab = .recipes
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingNewRecipeView) {
                RecipeContainerView(recipeSetupData: RecipeSetupData(), isShowingNewRecipeView: $isShowingNewRecipeView)
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(OvenMonitor())
}
