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
    @ObservedObject private var router = AppRouter.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("showDoughStatus") private var showDoughStatus = true
    @Query(filter: #Predicate<RecipeSetupData> { $0.isStarted == true || $0.isInProgress == true })
    private var activeRecipes: [RecipeSetupData]
    
    var body: some View {
        NavigationStack {
            TabView(selection: $router.selectedTab) {
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
                MenuAndShoppingView()
                    .tabItem {
                        Label("Menu", systemImage: "menucard")
                    }
                    .tag(MainTab.shopping)
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(MainTab.settings)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if showDoughStatus {
                    DoughStatusBar().padding(.vertical, 4)   // oben angeheftet, auch in Rezepten
                }
            }
            // Laufende Timer in die Dynamic Island schieben, sobald die App verlassen wird
            // (Live Activities dürfen nur im Vordergrund gestartet werden – .inactive gilt noch dazu)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { moveTimersToDynamicIsland() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Actions", systemImage: "ellipsis") {
                        Button("New Recipe", systemImage: "square.and.pencil") {
                            isShowingNewRecipeView.toggle()
                        }
                        Button("Open Recipe", systemImage: "folder") {
                            router.selectedTab = .recipes
                        }
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
            .sheet(isPresented: $isShowingNewRecipeView) {
                RecipeContainerView(recipeSetupData: RecipeSetupData(), isShowingNewRecipeView: $isShowingNewRecipeView)
            }
        }
    }
}

extension MainView {
    func moveTimersToDynamicIsland() {
        let manager = LiveActivityManager.shared
        manager.refreshDough(activeRecipes.filter(\.isStarted))
        for recipe in activeRecipes {
            if let end = recipe.kneadStepEnd, let step = recipe.currentKneadStep, end > Date() {
                manager.startKnead(recipe, title: recipe.kneadTitle(step), end: end)
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(OvenMonitor())
}
