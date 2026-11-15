//
//  MainView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftData
import SwiftUI

enum MainTab: Hashable {
    case activity, recipes, menu
}

struct MainView: View {
    @State private var isShowingNewRecipeView: Bool = false
    @State private var isShowingSettings: Bool = false
    @ObservedObject private var router = AppRouter.shared
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            TabView(selection: $router.selectedTab) {
                ActivityView()
                    .tabItem {
                        Label("Activity", systemImage: "house")
                    }
                    .tag(MainTab.activity)
                RecipesAndSaucesView()
                    .tabItem {
                        Label("Recipes", systemImage: "book")
                    }
                    .tag(MainTab.recipes)
                MenuAndShoppingView()
                    .tabItem {
                        Label("Menu", systemImage: "menucard")
                    }
                    .tag(MainTab.menu)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Recipe", systemImage: "plus") {
                        isShowingNewRecipeView.toggle()
                    }
                }
            }
            .navigationDestination(item: $router.openRecipe) { recipe in
                RecipeDetailView(recipeData: recipe)
            }
            .onAppear {
                SeedImporter.importIfNeeded(into: modelContext)
                DoughAnnouncer.shared.start(context: modelContext)
            }
            .sheet(isPresented: $isShowingSettings) {
                NavigationStack {
                    SettingsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { isShowingSettings = false }
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

/// Ein Tab für Teig- und Saucenrezepte, per Umschalter getrennt.
struct RecipesAndSaucesView: View {
    enum Kind: Hashable { case dough, sauce }
    @State private var kind: Kind = .dough

    var body: some View {
        VStack(spacing: 0) {
            Picker("Type", selection: $kind) {
                Text("Dough").tag(Kind.dough)
                Text("Sauce").tag(Kind.sauce)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 6)
            switch kind {
            case .dough: RecipesView()
            case .sauce: SauceListView()
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(OvenMonitor())
}
