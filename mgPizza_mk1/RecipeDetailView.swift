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
    @State private var isShowingShoppingPicker = false
    @State private var checkedIngredients: Set<String> = []

    private var isShowingTemplate: Binding<Bool> {
        Binding { templateRecipe != nil } set: { if !$0 { templateRecipe = nil } }
    }

    var body: some View {
        Form {
            phaseSection
            ingredientsSection
            KneadSection(recipe: recipeData)
            timerSection
            tipsSections
            feedbackSection
            settingsSection
        }
        .navigationTitle(recipeData.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Use as template", systemImage: "doc.on.doc") {
                    templateRecipe = recipeData.copyAsTemplate()
                }
            }
        }
        .sheet(isPresented: $isShowingShoppingPicker) {
            ShoppingPickerSheet(items: recipeData.shoppingItems, source: recipeData.displayName)
        }
        // sheet(item:) statt isPresented: sonst ist das Rezept beim ersten Öffnen noch nil (leeres Sheet)
        .sheet(item: $templateRecipe) { recipe in
            RecipeContainerView(recipeSetupData: recipe, isShowingNewRecipeView: isShowingTemplate)
        }
    }

    // MARK: 0 · Status

    var phaseSection: some View {
        Section {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                PhaseProgressView(phase: recipeData.phase(now: context.date))
            }
            if !recipeData.isActive {
                Button {
                    recipeData.beginSession()
                } label: {
                    Label("Bake now", systemImage: "play.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            } else if recipeData.phase() == .serve {
                Button {
                    recipeData.finishSession()
                } label: {
                    Label("Done – finish recipe", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: 1 · Zutaten

    var ingredientsSection: some View {
        Section {
            ForEach(ingredientRows, id: \.key) { row in
                Button {
                    if checkedIngredients.contains(row.key) { checkedIngredients.remove(row.key) } else { checkedIngredients.insert(row.key) }
                } label: {
                    HStack {
                        Image(systemName: checkedIngredients.contains(row.key) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkedIngredients.contains(row.key) ? .green : .gray)
                        Text(row.name)
                        Spacer()
                        Text(row.amount).bold().foregroundStyle(row.key == "yeast" ? .orange : .primary)
                    }
                }
                .foregroundStyle(.primary)
            }
            HStack {
                Text("Total")
                Spacer()
                Text("\(recipeData.totalDoughWeight, specifier: "%.0f") g").foregroundStyle(.secondary)
            }
            Button("Add to shopping list", systemImage: "cart.badge.plus") {
                isShowingShoppingPicker = true
            }
        } header: {
            Text("1 · Ingredients")
        } footer: {
            Text("Tap to tick off what you have weighed.")
        }
    }

    private var ingredientRows: [(key: String, name: String, amount: String)] {
        ["flour", "water", "salt", "oil", "sugar", "yeast"].compactMap { key -> (key: String, name: String, amount: String)? in
            guard let item = recipeData.amount(of: key) else { return nil }
            let format = key == "yeast" ? "%.2f g" : (item.grams < 50 ? "%.1f g" : "%.0f g")
            return (key, item.name, String(format: format, item.grams))
        }
    }

    // MARK: 3 · Gare & Timer

    var timerSection: some View {
        Section {
            if recipeData.isStarted {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ActiveDoughRow(recipe: recipeData, now: context.date, showsName: false)
                }
                Button("Stop timer", systemImage: "stop.circle", role: .destructive) {
                    recipeData.stopTimers()
                }
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let cool = recipeData.effectiveCoolTime(now: context.date)
                    let out = context.date.addingTimeInterval(cool * 3600)
                    let serving = out.addingTimeInterval(recipeData.roomTime * 3600)
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Fridge", value: "\(Int(cool.rounded())) h @ \(Int(recipeData.coolTemp)) °C")
                        LabeledContent("Room", value: "\(Int(recipeData.roomTime.rounded())) h @ \(Int(recipeData.roomTemp)) °C")
                        if cool > 0 {
                            LabeledContent("Out of the fridge") { Text(out, format: .dateTime.weekday().hour().minute()) }
                        }
                        LabeledContent("Serving") { Text(serving, format: .dateTime.weekday().hour().minute()) }
                    }
                    .font(.callout)
                }
                Button {
                    DoughNotifications.requestAuthorization()
                    recipeData.isInProgress = true
                    recipeData.startTimers()
                } label: {
                    Label("Into the fridge – start timer", systemImage: "refrigerator.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(recipeData.isKneadFinished ? .blue : .gray)
            }
        } header: {
            Text("3 · Proof & timer")
        } footer: {
            if !recipeData.isStarted {
                Text("Start when kneading is done. Reminders: 1 h before and when the dough comes out of the fridge, and at serving time.")
            }
        }
    }

    // MARK: Tipps

    @ViewBuilder
    var tipsSections: some View {
        FlourHintSection(totalHours: recipeData.roomTime + (recipeData.isStarted ? recipeData.coolTime : recipeData.effectiveCoolTime()))
        DoughWarningsSection(recipe: recipeData)
        if recipeData.isDetroit {
            DetroitTipsSection()
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

    // MARK: Rezept-Einstellungen

    var settingsSection: some View {
        Section("Recipe") {
            TextField("Name", text: $recipeData.name)
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
            LabeledContent("Yeast Correction", value: "\(Int(recipeData.yeastCorrection)) %")
            Button("Use as template", systemImage: "doc.on.doc") {
                templateRecipe = recipeData.copyAsTemplate()
            }
        }
    }
}

/// Fortschritt: Zutaten → Kneten → Kühlschrank → Raumgare → Servieren
struct PhaseProgressView: View {
    var phase: RecipeSetupData.Phase?

    private let items: [(RecipeSetupData.Phase, LocalizedStringKey, String)] = [
        (.ingredients, "Ingredients", "scalemass"),
        (.knead, "Knead", "timer"),
        (.fridge, "Fridge", "refrigerator"),
        (.room, "Room", "thermometer.medium"),
        (.serve, "Serve", "fork.knife"),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(items, id: \.0) { item in
                let state = stateFor(item.0)
                VStack(spacing: 4) {
                    Image(systemName: state == .done ? "checkmark.circle.fill" : item.2)
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(state == .current ? Color.orange.opacity(0.25) : Color.clear))
                        .foregroundStyle(state == .done ? .green : (state == .current ? .orange : .gray))
                    Text(item.1)
                        .font(.caption2)
                        .foregroundStyle(state == .current ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }

    private enum StepState { case done, current, open }

    private func stateFor(_ item: RecipeSetupData.Phase) -> StepState {
        guard let phase else { return .open }
        if item.rawValue < phase.rawValue { return .done }
        return item == phase ? .current : .open
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
