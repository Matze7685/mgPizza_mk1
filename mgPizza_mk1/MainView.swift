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
