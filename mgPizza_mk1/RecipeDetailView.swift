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
    @State private var templateRecipe: RecipeSetupData?

    private var isShowingTemplate: Binding<Bool> {
        Binding { templateRecipe != nil } set: { if !$0 { templateRecipe = nil } }
    }
    @State private var isShowingShoppingPicker = false
    
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $recipeData.name)
            }
            DoughIngredientsSection(recipe: recipeData)
            Section("Settings") {
                if recipeData.isDetroit {
                    LabeledContent("Pans", value: "\(Int(recipeData.doughBallsCount)) × \(Int(recipeData.panWidth))×\(Int(recipeData.panLength)) cm")
                    LabeledContent("Dough per Pan", value: "\(Int(recipeData.doughWeight)) g (\(String(format: "%.1f", recipeData.doughThickness)) mm)")
                } else {
                    LabeledContent("Dough Balls", value: "\(Int(recipeData.doughBallsCount)) × \(Int(recipeData.doughWeight)) g")
                }
                LabeledContent("Water", value: "\(Int(recipeData.waterRatio)) %")
                LabeledContent("Salt", value: String(format: "%.1f %%", recipeData.saltRatio))
                if recipeData.oilRatio > 0 { LabeledContent("Olive Oil", value: String(format: "%.1f %%", recipeData.oilRatio)) }
                if recipeData.sugarRatio > 0 { LabeledContent("Sugar", value: String(format: "%.1f %%", recipeData.sugarRatio)) }
                LabeledContent("Fridge", value: "\(Int(recipeData.coolTime)) h @ \(Int(recipeData.coolTemp)) °C")
                LabeledContent("Room", value: "\(Int(recipeData.roomTime)) h @ \(Int(recipeData.roomTemp)) °C")
                LabeledContent("Yeast Correction", value: "\(Int(recipeData.yeastCorrection)) %")
            }
            DoughWarningsSection(recipe: recipeData)
            FlourHintSection(totalHours: recipeData.roomTime + recipeData.coolTime)
            if recipeData.isDetroit {
                DetroitTipsSection()
            }
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
        // sheet(item:) statt isPresented: sonst ist das Rezept beim ersten Öffnen noch nil (leeres Sheet)
        .sheet(item: $templateRecipe) { recipe in
            RecipeContainerView(recipeSetupData: recipe, isShowingNewRecipeView: isShowingTemplate)
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

struct DetroitTipsSection: View {
    var body: some View {
        Section("Detroit – how to") {
            Label("Oil the pan well (1–2 tbsp), put the cold-fermented dough in and press it out.", systemImage: "1.circle")
            Label("If it shrinks back: rest 15–20 min, then press into the corners again.", systemImage: "2.circle")
            Label("Proof covered 2–3 h at room temperature until puffy.", systemImage: "3.circle")
            Label("Cheese (cubed Brick, young Gouda or Mozzarella) all the way to the edges – that makes the crispy rim.", systemImage: "4.circle")
            Label("Sauce in 2–3 stripes on top, after or before baking.", systemImage: "5.circle")
            Label("Oven: 260–290 °C on the lowest rack, 12–15 min, until the cheese rim is dark.", systemImage: "6.circle")
        }
        Section(header: Text("Detroit in the Ooni (pan with lid)"),
                footer: Text("Use the stone temperature as a guide – the oven thermometer probe helps here.")) {
            Label("Heat the stone to ~300–350 °C, then turn the flame to the lowest setting.", systemImage: "flame")
            Label("Pan in with lid on: 8–10 min so the dough bakes through and the base crisps without burning the top.", systemImage: "1.circle")
            Label("Rotate the pan 90° every 2–3 min – the back near the flame gets hotter.", systemImage: "2.circle")
            Label("Lid off: 2–4 min to brown cheese and rim, watch closely.", systemImage: "3.circle")
            Label("Check the base with a spatula – if it's pale, give it 1–2 more min with the lid on.", systemImage: "4.circle")
        }
        .font(.callout)
    }
}

#Preview {
    let recipe = RecipeSetupData(doughBallsCount: 2)
    NavigationStack { RecipeDetailView(recipeData: recipe) }
}
