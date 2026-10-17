//
//  RecipeDetailView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 25.09.26.
//

import SwiftData
import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var recipeData: RecipeSetupData
    @State private var isShowingTemplate = false
    @State private var templateRecipe: RecipeSetupData?
    @State private var isShowingShoppingPicker = false
    
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $recipeData.name)
            }
            DoughIngredientsSection(recipe: recipeData)
            Section("Settings") {
                LabeledContent("Dough Balls", value: "\(Int(recipeData.doughBallsCount)) × \(Int(recipeData.doughWeight)) g")
                LabeledContent("Water", value: "\(Int(recipeData.waterRatio)) %")
                LabeledContent("Salt", value: String(format: "%.1f %%", recipeData.saltRatio))
                if recipeData.oilRatio > 0 { LabeledContent("Olive Oil", value: String(format: "%.1f %%", recipeData.oilRatio)) }
                if recipeData.sugarRatio > 0 { LabeledContent("Sugar", value: String(format: "%.1f %%", recipeData.sugarRatio)) }
                LabeledContent("Fridge", value: "\(Int(recipeData.coolTime)) h @ \(Int(recipeData.coolTemp)) °C")
                LabeledContent("Room", value: "\(Int(recipeData.roomTime)) h @ \(Int(recipeData.roomTemp)) °C")
                LabeledContent("Yeast Correction", value: "\(Int(recipeData.yeastCorrection)) %")
            }
            DoughWarningsSection(recipe: recipeData)
            timerSection
            Section {
                NavigationLink {
                    KneadTimerView(recipe: recipeData)
                } label: {
                    Label("Knead Timer", systemImage: "timer")
                }
                Button("Add to shopping list", systemImage: "cart.badge.plus") {
                    isShowingShoppingPicker = true
                }
                Button {
                    templateRecipe = recipeData.copyAsTemplate()
                    isShowingTemplate = true
                } label: {
                    Label("Use as template", systemImage: "doc.on.doc")
                }
            }
            feedbackSection
        }
        .navigationTitle(recipeData.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingShoppingPicker) {
            ShoppingPickerSheet(items: recipeData.shoppingItems, source: recipeData.displayName)
        }
        .sheet(isPresented: $isShowingTemplate) {
            if let templateRecipe {
                RecipeContainerView(recipeSetupData: templateRecipe, isShowingNewRecipeView: $isShowingTemplate)
            }
        }
    }

    var timerSection: some View {
        Section("Timer") {
            if recipeData.isStarted {
                if let out = recipeData.fridgeOutDate, recipeData.coolTime > 0 {
                    LabeledContent("Out of the fridge") {
                        Text(out, format: .dateTime.weekday().hour().minute())
                    }
                }
                if let serving = recipeData.servingDate {
                    LabeledContent("Serving") {
                        Text(serving, format: .dateTime.weekday().hour().minute())
                    }
                }
                Button("Stop timer", systemImage: "stop.circle", role: .destructive) {
                    recipeData.stopTimers()
                }
            } else {
                Text("Starting now uses the same settings again (fridge \(Int(recipeData.coolTime)) h + room \(Int(recipeData.roomTime)) h).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Start dough timer", systemImage: "play.circle") {
                    DoughNotifications.requestAuthorization()
                    recipeData.fridgeTimeMode = "MAN"
                    recipeData.startTimers()
                }
            }
        }
    }

    var feedbackSection: some View {
        Section(header: Text("Feedback"), footer: Text("What was good, what should change next time? (crust, crumb, taste, handling …)")) {
            StarRatingView(rating: $recipeData.rating, size: 28, isEditable: true)
                .frame(maxWidth: .infinity)
            TextField("Notes", text: $recipeData.notes, axis: .vertical)
                .lineLimit(4...12)
        }
    }
}

#Preview {
    let recipe = RecipeSetupData(doughBallsCount: 2)
    NavigationStack { RecipeDetailView(recipeData: recipe) }
}
