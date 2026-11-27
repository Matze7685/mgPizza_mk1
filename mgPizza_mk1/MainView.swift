//
//  MainView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftData
import SwiftUI

enum MainTab: Hashable {
    case activity, recipes, events, shopping
}

struct MainView: View {
    @State private var isShowingSettings: Bool = false
    @ObservedObject private var router = AppRouter.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppKeys.showDoughStatus) private var showDoughStatus = true
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
                EventsView()
                    .tabItem {
                        Label("Events", systemImage: "party.popper")
                    }
                    .tag(MainTab.events)
                ShoppingListView()
                    .tabItem {
                        Label("Shopping", systemImage: "cart")
                    }
                    .tag(MainTab.shopping)
            }
            .onReceive(NotificationCenter.default.publisher(for: .showShoppingList)) { _ in router.selectedTab = .shopping }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    if let problem = StoreProblem.message {
                        // Datenbank ließ sich nicht öffnen: App läuft ohne gespeicherte Daten
                        Label("Saved data could not be opened. Changes are not kept. (\(problem))",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.15))
                    }
                    // Nicht auf der Startseite: dort steht der Teigstatus schon groß in der Karte
                    if showDoughStatus && router.selectedTab != .activity {
                        DoughStatusBar().padding(.vertical, 4)   // oben angeheftet, in Rezepten und Karte
                    }
                }
            }
            // Laufende Timer in die Dynamic Island schieben, sobald die App verlassen wird
            // (Live Activities dürfen nur im Vordergrund gestartet werden – .inactive gilt noch dazu)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    try? modelContext.save()   // Timer-Stand sichern, falls iOS die App im Hintergrund beendet
                    moveTimersToDynamicIsland()
                    AppRouter.updateShortcuts()
                    WidgetSnapshot.update(context: modelContext)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Recipe", systemImage: "plus") {
                        router.showNewRecipe = true
                    }
                }
            }
            .navigationDestination(item: $router.openRecipe) { recipe in
                RecipeDetailView(recipeData: recipe)
            }
            .onAppear {
                SeedImporter.importIfNeeded(into: modelContext)
                DoughAnnouncer.shared.start(context: modelContext)
                AppRouter.updateShortcuts()
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
            .sheet(isPresented: $router.showNewRecipe) {
                RecipeContainerView(recipeSetupData: RecipeSetupData(), isShowingNewRecipeView: $router.showNewRecipe)
            }
            // Schnellaktion „Geteilte Ansicht“
            .fullScreenCover(isPresented: $router.showFoldView) {
                OrdersFoldView()
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
