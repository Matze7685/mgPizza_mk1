//
//  DoughSettingsView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import SwiftData
import SwiftUI
import UserNotifications

/// Neues Rezept / Vorlage: eine Seite im Stil der Zubereitung.
/// Oben das Ergebnis (rechnet live mit), darunter aufklappbare Bereiche, unten Speichern / Jetzt backen.
struct DoughSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var recipeSetupData: RecipeSetupData
    @Binding var isShowingNewRecipeView: Bool

    /// Aufgeklappte Bereiche: 1 Teig, 2 Hefe & Extras, 3 Gare & Zeitplan
    @State private var expanded: Set<Int> = [1, 3]
    @State private var isShowingShoppingPicker = false

    private var recipe: RecipeSetupData { recipeSetupData }

    var body: some View {
        Form {
            resultSection
            doughSection
            yeastSection
            scheduleSection
        }
        .navigationTitle("Dough Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel", systemImage: "xmark") {
                    isShowingNewRecipeView = false
                }
            }
        }
        .safeAreaInset(edge: .bottom) { actionButtons }
        .sheet(isPresented: $isShowingShoppingPicker) {
            ShoppingPickerSheet(items: recipe.shoppingItems, source: recipe.displayName)
        }
        .onAppear(perform: migrateAutoMode)
        .onChange(of: recipe.style) { _, newStyle in applyStyleDefaults(newStyle) }
        .onChange(of: recipe.panWidth) { recipe.applyDetroitWeight() }
        .onChange(of: recipe.panLength) { recipe.applyDetroitWeight() }
        .onChange(of: recipe.doughThickness) { recipe.applyDetroitWeight() }
        .onChange(of: recipe.dateSelection) { servingChanged() }
        .onChange(of: recipe.fridgeOutSelection) { fridgeOutChanged() }
    }

    // MARK: Ergebnis

    var resultSection: some View {
        Section {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                resultCard(now: context.date)
            }
            Button("Add to shopping list", systemImage: "cart.badge.plus") {
                isShowingShoppingPicker = true
            }
        } header: {
            Text("Result")
        }
    }

    private func resultCard(now: Date) -> some View {
        let cool = recipe.effectiveCoolTime(now: now)
        let serving = recipe.isTimeOfDayMode ? recipe.dateSelection : now.addingTimeInterval((cool + recipe.roomTime) * 3600)
        let totalHours = cool + recipe.roomTime
        let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3)
        return VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(["flour", "water", "salt", "yeast", "oil", "sugar"], id: \.self) { key in
                    if let item = recipe.amount(of: key) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(format: key == "yeast" ? "%.2f g" : (item.grams < 50 ? "%.1f g" : "%.0f g"), item.grams))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(key == "yeast" ? .orange : .primary)
                            Text(item.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            Group {
                if recipe.isDetroit {
                    Text("\(Int(recipe.doughBallsCount))× \(Int(recipe.doughWeight)) g per pan · total \(Int(recipe.totalDoughWeight)) g")
                } else {
                    Text("\(Int(recipe.doughBallsCount))× \(Int(recipe.doughWeight)) g (≈ \(Int(recipe.pizzaDiameter.rounded())) cm) · total \(Int(recipe.totalDoughWeight)) g")
                }
            }
            .font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack {
                Label {
                    Text(serving, format: .dateTime.weekday().day().month().hour().minute())
                } icon: {
                    Image(systemName: "fork.knife")
                }
                .font(.callout)
                Spacer()
                // Mehl-Tipp in einer Zeile (Details unter „Mehr“ in der Zubereitung)
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(totalHours > 24 ? Color.red : Color.blue)
                        .frame(width: 5, height: 16)
                    Text(totalHours > 24 ? "Caputo red" : "Caputo blue").font(.caption)
                }
            }
            if recipe.batchCount > 1 {
                Label("Kneaded in \(recipe.batchCount) batches (max. \(Int(RecipeSetupData.mixerCapacity)) g per batch).",
                      systemImage: "square.split.2x1")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: 1 · Teig

    var doughSection: some View {
        Section {
            if expanded.contains(1) {
                TextField(recipe.autoName, text: $recipeSetupData.name)
                Picker("Style", selection: $recipeSetupData.style) {
                    Text("Round").tag("round")
                    Text("Detroit").tag("detroit")
                }
                .pickerStyle(.segmented)
                if recipe.isDetroit {
                    Stepper("Pans: \(Int(recipe.doughBallsCount))", value: $recipeSetupData.doughBallsCount, in: 1...20)
                    slider("Pan Width: \(Int(recipe.panWidth)) cm", value: $recipeSetupData.panWidth, in: 10...50, step: 1)
                    slider("Pan Length: \(Int(recipe.panLength)) cm", value: $recipeSetupData.panLength, in: 10...60, step: 1)
                    VStack(alignment: .leading) {
                        Text("Dough Thickness: \(recipe.doughThickness, specifier: "%.1f") mm")
                        Slider(value: $recipeSetupData.doughThickness, in: 3...25, step: 0.5)
                        Text("Raw dough pressed into the pan. ~5–6 mm = classic (rises to ~2.5–3 cm), 8–12 mm = thick, 15+ mm = very thick / focaccia-like.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    LabeledContent("Dough per Pan", value: "\(Int(recipe.doughWeight)) g")
                } else {
                    Stepper("Dough Balls: \(Int(recipe.doughBallsCount))", value: $recipeSetupData.doughBallsCount, in: 1...60)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dough Weight: \(Int(recipe.doughWeight)) g")
                        Slider(value: $recipeSetupData.doughWeight, in: 100...2000, step: 10)
                        Text("≈ \(Int(recipe.pizzaDiameter.rounded())) cm pizza")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                slider("Water: \(Int(recipe.waterRatio)) %", value: $recipeSetupData.waterRatio, in: 50...90, step: 1, warning: .water)
                slider("Salt: \(recipe.saltRatio, specifier: "%.1f") %", value: $recipeSetupData.saltRatio, in: 1.0...4.0, step: 0.1, warning: .salt)
            }
        } header: {
            sectionHeader(1, "1 · Dough", summary: doughSummary)
        }
    }

    private var doughSummary: String {
        "\(Int(recipe.doughBallsCount))× \(Int(recipe.doughWeight)) g · \(Int(recipe.waterRatio)) % · \(String(format: "%.1f", recipe.saltRatio)) %"
    }

    // MARK: 2 · Hefe & Extras

    var yeastSection: some View {
        Section {
            if expanded.contains(2) {
                Picker("Yeast Type", selection: $recipeSetupData.yeastSelection) {
                    Text("Fresh").tag(0)
                    Text("Dry").tag(1)
                    Text("Instant Dry").tag(2)
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading) {
                    Text("Yeast Correction: \(Int(recipe.yeastCorrection)) %")
                    Slider(value: $recipeSetupData.yeastCorrection, in: 25...200, step: 5)
                    Text("Lower it if your dough over-proofs, raise it if it stays too flat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                slider("Olive Oil: \(recipe.oilRatio, specifier: "%.1f") %", value: $recipeSetupData.oilRatio, in: 0...5, step: 0.5, warning: .oil)
                slider("Sugar: \(recipe.sugarRatio, specifier: "%.1f") %", value: $recipeSetupData.sugarRatio, in: 0...3, step: 0.5)
            }
        } header: {
            sectionHeader(2, "2 · Yeast & extras", summary: yeastSummary)
        } footer: {
            if expanded.contains(2) {
                Text("Oil and sugar help browning in home ovens / gas grills below ~400 °C. Leave at 0 for Neapolitan style.")
            }
        }
    }

    private var yeastSummary: String {
        var parts = [recipe.yeastName]
        if recipe.yeastCorrection != 100 { parts.append("\(Int(recipe.yeastCorrection)) %") }
        if recipe.oilRatio > 0 { parts.append(String(localized: "Olive Oil")) }
        if recipe.sugarRatio > 0 { parts.append(String(localized: "Sugar")) }
        return parts.joined(separator: " · ")
    }

    // MARK: 3 · Gare & Zeitplan

    var scheduleSection: some View {
        Section {
            if expanded.contains(3) {
                Picker("Plan by", selection: planModeBinding) {
                    Text("Hours").tag(false)
                    Text("Time of day").tag(true)
                }
                .pickerStyle(.segmented)
                if recipe.isTimeOfDayMode {
                    DatePicker("Serving", selection: $recipeSetupData.dateSelection,
                               in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Out of the fridge", selection: $recipeSetupData.fridgeOutSelection,
                               in: Date()...max(Date(), recipe.dateSelection), displayedComponents: [.date, .hourAndMinute])
                    LabeledContent("Fridge Time", value: hours(recipe.effectiveCoolTime()))
                    LabeledContent("Room Time", value: hours(recipe.roomTime))
                } else {
                    Stepper("Fridge Time: \(Int(recipe.coolTime)) h", value: $recipeSetupData.coolTime, in: 0...72)
                    Stepper("Room Time: \(Int(recipe.roomTime)) h", value: $recipeSetupData.roomTime, in: 0...48)
                }
                InlineDoughWarning(recipe: recipe, field: .fridge)
                Stepper("Fridge Temperature: \(Int(recipe.coolTemp)) °C", value: $recipeSetupData.coolTemp, in: 1...10)
                VStack(alignment: .leading, spacing: 4) {
                    Stepper("Room Temperature: \(Int(recipe.roomTemp)) °C", value: $recipeSetupData.roomTemp, in: 10...30)
                    InlineDoughWarning(recipe: recipe, field: .room)
                }
            }
        } header: {
            sectionHeader(3, "3 · Proof & schedule", summary: scheduleSummary)
        } footer: {
            if expanded.contains(3) {
                if recipe.isTimeOfDayMode {
                    Text("Fridge time = now until out of the fridge. Room time = out of the fridge until serving.")
                } else {
                    Text("Flow: knead → fridge → take out & portion → room proof → serve")
                }
            }
        }
    }

    private var scheduleSummary: String {
        "\(hours(recipe.effectiveCoolTime())) + \(hours(recipe.roomTime))"
    }

    // MARK: Buttons

    var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                saveRecipe()
                isShowingNewRecipeView = false
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button(action: startButtonProcess) {
                Label("Bake now", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: Bausteine

    private func sectionHeader(_ group: Int, _ title: LocalizedStringKey, summary: String) -> some View {
        Button {
            withAnimation {
                if expanded.contains(group) { expanded.remove(group) } else { expanded.insert(group) }
            }
        } label: {
            HStack {
                Text(title)
                if !expanded.contains(group) {
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

    /// Regler mit Beschriftung und – falls nötig – Warnung direkt darunter
    private func slider(_ title: LocalizedStringKey, value: Binding<Double>, in range: ClosedRange<Double>, step: Double,
                        warning: DoughWarningsSection.Field? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Slider(value: value, in: range, step: step)
            if let warning {
                InlineDoughWarning(recipe: recipe, field: warning)
            }
        }
    }

    private func hours(_ value: Double) -> String {
        let total = Int((value * 60).rounded())
        return total % 60 == 0 ? "\(total / 60) h" : String(format: "%d h %02d min", total / 60, total % 60)
    }

    // MARK: Zeitplan-Logik

    /// "Nach Stunden" (MAN) oder "Nach Uhrzeit" (OUT: Servieren + Raus aus dem Kühlschrank)
    private var planModeBinding: Binding<Bool> {
        Binding {
            recipe.isTimeOfDayMode
        } set: { byTime in
            if byTime {
                // Vorschlag aus den bisherigen Stunden, auf die nächste halbe Stunde gerundet
                let serving = Date().addingTimeInterval((recipe.coolTime + recipe.roomTime) * 3600)
                let step: TimeInterval = 30 * 60
                recipe.dateSelection = Date(timeIntervalSinceReferenceDate: (serving.timeIntervalSinceReferenceDate / step).rounded(.up) * step)
                recipe.fridgeOutSelection = max(Date(), recipe.dateSelection.addingTimeInterval(-recipe.roomTime * 3600))
                recipe.fridgeTimeMode = "OUT"
                updateRoomTime()
            } else {
                recipe.coolTime = recipe.effectiveCoolTime().rounded()
                recipe.roomTime = recipe.roomTime.rounded()
                recipe.fridgeTimeMode = "MAN"
            }
        }
    }

    /// Früheres AUTO (nur Servierzeit) wird zu "Nach Uhrzeit"
    private func migrateAutoMode() {
        guard recipe.fridgeTimeMode == "AUTO" else { return }
        recipe.fridgeOutSelection = max(Date(), recipe.dateSelection.addingTimeInterval(-recipe.roomTime * 3600))
        recipe.fridgeTimeMode = "OUT"
        updateRoomTime()
    }

    /// Servierzeit verschoben: Raumzeit bleibt, Rausnehm-Zeitpunkt wandert mit
    private func servingChanged() {
        guard recipe.isTimeOfDayMode else { return }
        let out = max(Date(), recipe.dateSelection.addingTimeInterval(-recipe.roomTime * 3600))
        if out != recipe.fridgeOutSelection { recipe.fridgeOutSelection = out }
        updateRoomTime()
    }

    private func fridgeOutChanged() {
        guard recipe.isTimeOfDayMode else { return }
        if recipe.dateSelection < recipe.fridgeOutSelection {
            recipe.dateSelection = recipe.fridgeOutSelection
        }
        updateRoomTime()
    }

    /// Raumzeit = aus dem Kühlschrank bis Servieren
    private func updateRoomTime() {
        recipe.roomTime = max(0, recipe.dateSelection.timeIntervalSince(recipe.fridgeOutSelection) / 3600)
    }

    private func applyStyleDefaults(_ newStyle: String) {
        if newStyle == "detroit" {
            // Typische Detroit-Werte: hohe Hydration, etwas Öl
            recipe.waterRatio = 72
            recipe.saltRatio = 2.5
            recipe.oilRatio = 2
            recipe.doughBallsCount = 1
            recipe.applyDetroitWeight()
        } else {
            recipe.doughWeight = 250
            recipe.waterRatio = 65
            recipe.saltRatio = 3
            recipe.oilRatio = 0
        }
        recipe.kneadSteps = KneadStep.plan(forStyle: newStyle)
    }

    // MARK: Speichern / Starten

    func startButtonProcess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                print("Fehler: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                // Jetzt backen = Rezept beginnen und direkt hineinwechseln (Zutaten -> Kneten -> Kühlschrank-Timer).
                // Gewählte Uhrzeiten bleiben erhalten, bis der Kühlschrank-Timer gestartet wird.
                saveRecipe(keepDateMode: true)
                recipe.beginSession()
                try? modelContext.save()
                isShowingNewRecipeView = false
                AppRouter.shared.open(recipe)
            }
        }
    }

    private func saveRecipe(keepDateMode: Bool = false) {
        // Uhrzeit-Plan in feste Stunden umrechnen, damit das gespeicherte Rezept reproduzierbar bleibt
        if !keepDateMode && recipe.fridgeTimeMode != "MAN" {
            recipe.coolTime = recipe.effectiveCoolTime().rounded()
            recipe.roomTime = recipe.roomTime.rounded()
            recipe.fridgeTimeMode = "MAN"
        }
        if recipe.modelContext == nil {
            modelContext.insert(recipe)
        }
        try? modelContext.save()
    }
}

extension RecipeSetupData {
    /// Zeitplan über Uhrzeiten (Servieren / raus aus dem Kühlschrank) statt Stunden
    var isTimeOfDayMode: Bool { fridgeTimeMode == "OUT" }
}

#Preview {
    let recipeSetupData = RecipeSetupData(doughBallsCount: 4, doughWeight: 300, waterRatio: 65, saltRatio: 3, yeastSelection: 1, fridgeTimeMode: "MAN", roomTemp: 27, roomTime: 12, coolTemp: 4, coolTime: 12, dateSelection: Date())
    NavigationStack {
        DoughSettingsView(recipeSetupData: recipeSetupData, isShowingNewRecipeView: .constant(true))
    }
}
