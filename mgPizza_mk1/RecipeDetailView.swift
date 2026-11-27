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
    @State private var shownBatch = 0
    /// Aufgeklappte Bereiche: 2 Abwiegen & Kneten, 3 Gare & Timer, 4 Mehr
    @State private var expanded: Set<Int> = [2]
    /// Abwiege-Liste im Knet-Bereich (aufgeklappt, solange noch nicht geknetet wird)
    @State private var isWeighExpanded = true
    /// Nach unten gescrollt: Fortschritt als schmale Symbolleiste oben anheften
    @State private var isStatusPinned = false

    private var isShowingTemplate: Binding<Bool> {
        Binding { templateRecipe != nil } set: { if !$0 { templateRecipe = nil } }
    }

    var body: some View {
        Form {
            phaseSection
            DoughWarningsSection(recipe: recipeData)
            KneadSection(recipe: recipeData, isExpanded: expanded.contains(2), onToggle: { toggle(2) },
                         ingredients: AnyView(weighGroup))
            timerSection
            moreSection
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 90
        } action: { _, pinned in
            withAnimation(.easeInOut(duration: 0.2)) { isStatusPinned = pinned }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if isStatusPinned {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    PhaseProgressView(phase: recipeData.phase(now: context.date), iconsOnly: true)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(.bar)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle(recipeData.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: recipeData.displayName) { recipeData.refreshScheduledTexts() }
        // Zutaten zeigen automatisch den aktuellen Knet-Durchgang
        .onAppear {
            shownBatch = recipeData.currentBatch
            expanded = [currentGroup]
            isWeighExpanded = recipeData.phase() != .knead
        }
        .onChange(of: currentGroup) { expanded = [currentGroup] }
        .onChange(of: recipeData.phase()) { isWeighExpanded = recipeData.phase() != .knead }
        .onChange(of: recipeData.kneadBatch) { shownBatch = recipeData.currentBatch }
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

    /// Bereich der aktuellen Phase (ohne laufendes Rezept: Abwiegen & Kneten)
    private var currentGroup: Int {
        switch recipeData.phase() {
        case nil, .ingredients: return 2
        case .knead: return recipeData.isKneadFinished ? 3 : 2   // alle Durchgänge fertig: Kneten zu, Gare auf
        default: return 3
        }
    }

    private func toggle(_ group: Int) {
        withAnimation {
            if expanded.contains(group) { expanded.remove(group) } else { expanded.insert(group) }
        }
    }

    private func sectionHeader(_ group: Int, _ title: LocalizedStringKey, summary: String? = nil) -> some View {
        Button { toggle(group) } label: {
            HStack {
                Text(title)
                if let summary, !expanded.contains(group) {
                    Text(summary).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(expanded.contains(group) ? 90 : 0))
            }
            .textCase(nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

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

    // MARK: 1 · Abwiegen (im Knet-Bereich)

    /// Abhak-Liste zum Abwiegen, aufklappbar oben im Bereich „Abwiegen & Kneten“
    var weighGroup: some View {
        DisclosureGroup(isExpanded: $isWeighExpanded) {
            if recipeData.batchCount > 1 {
                Label("Too much for the mixer – kneaded in \(recipeData.batchCount) batches (max. \(Int(RecipeSetupData.mixerCapacity)) g each).",
                      systemImage: "square.split.2x1")
                    .font(.callout)
                    .foregroundStyle(.orange)
                Picker("Batch", selection: $shownBatch) {
                    ForEach(0..<recipeData.batchCount, id: \.self) { batch in
                        Text("\(batch + 1)").tag(batch)
                    }
                }
                .pickerStyle(.segmented)
                Text("Batch \(shownBatch + 1): \(recipeData.batchBalls(shownBatch)) dough balls")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(ingredientRows, id: \.key) { row in
                let checkKey = "\(shownBatch)-\(row.key)"
                Button {
                    if checkedIngredients.contains(checkKey) { checkedIngredients.remove(checkKey) } else { checkedIngredients.insert(checkKey) }
                } label: {
                    HStack {
                        Image(systemName: checkedIngredients.contains(checkKey) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(checkedIngredients.contains(checkKey) ? .green : .gray)
                        Text(row.name)
                        Spacer()
                        Text(row.amount).bold().foregroundStyle(row.key == "yeast" ? .orange : .primary)
                    }
                }
                .foregroundStyle(.primary)
            }
            if recipeData.batchCount > 1 {
                HStack {
                    Text("Total (all batches)")
                    Spacer()
                    Text("\(recipeData.totalDoughWeight, specifier: "%.0f") g").foregroundStyle(.secondary)
                }
            }
        } label: {
            HStack {
                Label("Weigh ingredients", systemImage: "scalemass")
                Spacer()
                Text("\(recipeData.totalDoughWeight * recipeData.batchFraction(min(shownBatch, recipeData.batchCount - 1)), specifier: "%.0f") g")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ingredientRows: [(key: String, name: String, amount: String)] {
        let fraction = recipeData.batchFraction(min(shownBatch, recipeData.batchCount - 1))
        return ["flour", "water", "salt", "oil", "sugar", "yeast"].compactMap { key -> (key: String, name: String, amount: String)? in
            guard let item = recipeData.amount(of: key) else { return nil }
            let grams = item.grams * fraction
            let format = key == "yeast" ? "%.2f g" : (grams < 50 ? "%.1f g" : "%.0f g")
            return (key, item.name, String(format: format, grams))
        }
    }

    // MARK: 3 · Gare & Timer

    var timerSection: some View {
        Section {
            if !expanded.contains(3) {
                EmptyView()
            } else if recipeData.isStarted {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ActiveDoughRow(recipe: recipeData, now: context.date, showsName: false)
                }
                // Teiglinge formen: beim Herausnehmen aus dem Kühlschrank (bzw. sofort, ohne Kühlschrank)
                if recipeData.phase() == .fridge || (recipeData.phase() == .room && recipeData.coolTime == 0) {
                    Label(recipeData.shapingText, systemImage: recipeData.isDetroit ? "square.grid.2x2" : "circle.grid.3x3")
                        .font(.callout)
                        .foregroundStyle(.secondary)
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
                        .labelStyle(.titleAndIcon)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(recipeData.isKneadFinished ? .accentColor : .gray)
            }
        } header: {
            sectionHeader(3, "2 · Proof & timer", summary: timerSummary)
        } footer: {
            if expanded.contains(3) && !recipeData.isStarted {
                Text("Start when kneading is done. Reminders: 1 h before and when the dough comes out of the fridge, and at serving time.")
            }
        }
    }

    // MARK: Tipps

    private var timerSummary: String? {
        guard let serving = recipeData.servingDate, recipeData.isStarted else { return nil }
        return serving.formatted(.dateTime.weekday().hour().minute())
    }

    /// Selten gebrauchtes (Mehl-Tipp, Detroit-Anleitung, Feedback, Rezeptwerte) eingeklappt am Ende
    @ViewBuilder
    var moreSection: some View {
        Section {
            Button { toggle(4) } label: {
                HStack {
                    Label("More: shopping list, tips, feedback, recipe values", systemImage: "ellipsis.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expanded.contains(4) ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        if expanded.contains(4) {
            Section {
                Button("Add to shopping list", systemImage: "cart.badge.plus") {
                    isShowingShoppingPicker = true
                }
            }
            FlourHintSection(totalHours: recipeData.roomTime + (recipeData.isStarted ? recipeData.coolTime : recipeData.effectiveCoolTime()))
            if recipeData.isDetroit {
                DetroitTipsSection()
            }
            feedbackSection
            settingsSection
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
            TextField(recipeData.autoName, text: $recipeData.name)
            if recipeData.isDetroit {
                LabeledContent("Pans", value: "\(Int(recipeData.doughBallsCount)) × \(Int(recipeData.panWidth))×\(Int(recipeData.panLength)) cm")
                LabeledContent("Dough per Pan", value: "\(Int(recipeData.doughWeight)) g (\(String(format: "%.1f", recipeData.doughThickness)) mm)")
            } else {
                LabeledContent("Dough Balls", value: "\(Int(recipeData.doughBallsCount)) × \(Int(recipeData.doughWeight)) g (≈ \(Int(recipeData.pizzaDiameter.rounded())) cm)")
            }
            // Anteil (Bäckerprozent) und Gewicht fürs ganze Rezept
            LabeledContent("Flour", value: String(format: "100 %% · %.0f g", recipeData.flour))
            LabeledContent("Water", value: String(format: "%.0f %% · %.0f g", recipeData.waterRatio, recipeData.water))
            LabeledContent("Salt", value: String(format: "%.1f %% · %.1f g", recipeData.saltRatio, recipeData.salt))
            if recipeData.oilRatio > 0 { LabeledContent("Olive Oil", value: String(format: "%.1f %% · %.1f g", recipeData.oilRatio, recipeData.oil)) }
            if recipeData.sugarRatio > 0 { LabeledContent("Sugar", value: String(format: "%.1f %% · %.1f g", recipeData.sugarRatio, recipeData.sugar)) }
            LabeledContent(recipeData.yeastName, value: String(format: "%.2f %% · %.2f g", recipeData.flour > 0 ? recipeData.yeast() / recipeData.flour * 100 : 0, recipeData.yeast()))
            LabeledContent("Yeast Correction", value: "\(Int(recipeData.yeastCorrection)) %")
        }
    }
}

/// Fortschritt: Zutaten → Kneten → Kühlschrank → Raumgare → Servieren
struct PhaseProgressView: View {
    var phase: RecipeSetupData.Phase?
    /// Kompakt (angeheftet beim Scrollen): nur Symbole, ohne Beschriftung
    var iconsOnly = false

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
                        .font(iconsOnly ? .body : .title3)
                        .frame(width: iconsOnly ? 28 : 36, height: iconsOnly ? 28 : 36)
                        .background(Circle().fill(state == .current ? Theme.doughHighlight : Color.clear))
                        .foregroundStyle(state == .done ? .green : (state == .current ? .orange : .gray))
                    if !iconsOnly {
                        Text(item.1)
                            .font(.caption2)
                            .foregroundStyle(state == .current ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, iconsOnly ? 0 : 4)
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
