//
//  DoughResultView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import SwiftData
import SwiftUI
import UserNotifications

struct DoughResultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var recipeSetupData: RecipeSetupData
    @Binding var path: NavigationPath
    @Binding var isShowingNewRecipeView: Bool
    
    var body: some View {
        Form {
            DoughIngredientsSection(recipe: recipeSetupData)
            doughSection
            fermentSection
            DoughWarningsSection(recipe: recipeSetupData)
            FlourHintSection(totalHours: recipeSetupData.roomTime + recipeSetupData.effectiveCoolTime())
        }
        .navigationTitle("Result").font(.subheadline)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", systemImage: "chevron.left") {
                    path.removeLast()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel", systemImage: "xmark") {
                    isShowingNewRecipeView = false
                }
            }
        }
        
        saveAndStartButton
    }
    
    var doughSection: some View {
        Section(header: Text("")) {
            HStack {
                Text(recipeSetupData.isDetroit ? LocalizedStringKey("Pans") : "Dough Balls")
                Spacer()
                Text("\(recipeSetupData.doughBallsCount, specifier: "%.0f")").bold()
            }
            if recipeSetupData.isDetroit {
                HStack {
                    Text("Pan Size")
                    Spacer()
                    Text("\(Int(recipeSetupData.panWidth)) × \(Int(recipeSetupData.panLength)) cm · \(recipeSetupData.doughThickness, specifier: "%.1f") mm").bold()
                }
            }
            HStack {
                Text(recipeSetupData.isDetroit ? LocalizedStringKey("Dough per Pan") : "Dough Balls Weight")
                Spacer()
                Text("\(recipeSetupData.doughWeight, specifier: "%.0f") g").bold()
            }
        }
        .listSectionSpacing(0)
    }
    var fermentSection: some View {
        let coolTime = recipeSetupData.effectiveCoolTime()
        let fridgeOut = Date().addingTimeInterval(coolTime * 3600)
        let serving = fridgeOut.addingTimeInterval(recipeSetupData.roomTime * 3600)
        return Section(header: Text(""), footer: Text("Flow: knead → fridge → take out & portion → room proof → serve")) {
            HStack {
                Text("Fridge Time")
                Spacer()
                Text("\(coolTime, specifier: "%.0f") h").bold()
            }
            HStack {
                Text("Fridge Temperature")
                Spacer()
                Text("\(recipeSetupData.coolTemp, specifier: "%.0f") °C").bold()
            }
            HStack {
                Text("Room Time")
                Spacer()
                Text("\(recipeSetupData.roomTime, specifier: "%.0f") h").bold()
            }
            HStack {
                Text("Room Temperature")
                Spacer()
                Text("\(recipeSetupData.roomTemp, specifier: "%.0f") °C").bold()
            }
            if coolTime > 0 {
                HStack {
                    Text("Out of the fridge")
                    Spacer()
                    Text(fridgeOut, format: .dateTime.weekday().hour().minute()).bold()
                }
            }
            HStack {
                Text("Serving")
                Spacer()
                Text(serving, format: .dateTime.weekday().hour().minute()).bold()
            }
        }
        .listSectionSpacing(0)
    }
    var saveAndStartButton: some View {
        HStack {
            Button{
                saveRecipe()
                isShowingNewRecipeView = false
            } label: {
                HStack {
                    Spacer()
                    Text("SAVE")
                        .foregroundStyle(Color.black)
                        .bold()
                    Spacer()
                }
            }
            .padding()
            .background(Color.blue)
            .clipShape(.capsule)
            
            Button{
                startButtonProcess()
            } label: {
                HStack {
                    Spacer()
                    Text("START")
                        .foregroundStyle(Color.black)
                        .bold()
                    Spacer()
                }
            }
            .padding()
            .background(Color.green)
            .clipShape(.capsule)
        }
        .padding(.horizontal)
    }
    
    func startButtonProcess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Fehler: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                // START = Rezept beginnen und direkt hineinwechseln (Zutaten -> Kneten -> Kühlschrank-Timer).
                // Gewählte Datum/Uhrzeit-Zeitpunkte bleiben erhalten, bis der Kühlschrank-Timer gestartet wird.
                saveRecipe(keepDateMode: true)
                recipeSetupData.beginSession()
                try? modelContext.save()
                isShowingNewRecipeView = false
                AppRouter.shared.open(recipeSetupData)
            }
        }
    }
    
    private func saveRecipe(keepDateMode: Bool = false) {
        // AUTO-Kühlzeit fest übernehmen, damit das gespeicherte Rezept reproduzierbar bleibt
        if !keepDateMode && recipeSetupData.fridgeTimeMode != "MAN" {
            recipeSetupData.coolTime = recipeSetupData.effectiveCoolTime().rounded()
            recipeSetupData.fridgeTimeMode = "MAN"
        }
        if recipeSetupData.modelContext == nil {
            modelContext.insert(recipeSetupData)
        }
        try? modelContext.save()
    }
}

/// Zutatenliste – wird im Ergebnis und in der Rezept-Detailansicht verwendet.
struct DoughIngredientsSection: View {
    var recipe: RecipeSetupData

    var body: some View {
        Section(header: Text("Ingredients")) {
            row("Flour", recipe.flour, "%.0f g")
            row("Water", recipe.water, "%.0f g")
            row("Salt", recipe.salt, "%.1f g")
            if recipe.oil > 0 { row("Olive Oil", recipe.oil, "%.1f g") }
            if recipe.sugar > 0 { row("Sugar", recipe.sugar, "%.1f g") }
            HStack {
                Text(recipe.yeastName)
                Spacer()
                Text("\(recipe.yeast(), specifier: "%.2f") g").bold().foregroundColor(.orange)
            }
            HStack {
                Text("Total")
                Spacer()
                Text("\(recipe.totalDoughWeight, specifier: "%.0f") g").foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ title: LocalizedStringKey, _ value: Double, _ format: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(String(format: format, value)).bold()
        }
    }
}

/// Gedankenstütze Mehlwahl: Caputo rot (Cuoco) für lange, Caputo blau (Pizzeria) für kurze Gare.
struct FlourHintSection: View {
    var totalHours: Double

    private var isLong: Bool { totalHours > 24 }

    var body: some View {
        Section {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isLong ? Color.red : Color.blue)
                    .frame(width: 8, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isLong ? "Use Caputo red" : "Use Caputo blue").font(.headline)
                    Text("Total proof \(Int(totalHours.rounded())) h").font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Flour")
        } footer: {
            Text("Caputo red (Cuoco): more than 24 h. Caputo blue (Pizzeria): less than 24 h.")
        }
    }
}

/// Plausibilitätsprüfung der Teigverhältnisse.
struct DoughWarningsSection: View {
    var recipe: RecipeSetupData

    var warnings: [LocalizedStringKey] {
        var result: [LocalizedStringKey] = []
        if recipe.waterRatio < 58 { result.append("Hydration below \(58)% gives a dry, dense crust.") }
        if recipe.waterRatio > 75 { result.append("Hydration above \(75)% is hard to handle – use strong flour (W300+).") }
        if recipe.saltRatio < 2.2 { result.append("Salt below \(2.2, specifier: "%.1f")% tastes flat and weakens the gluten.") }
        if recipe.saltRatio > 3.2 { result.append("Salt above \(3.2, specifier: "%.1f")% slows the yeast noticeably.") }
        if recipe.roomTemp >= 26 && recipe.roomTime >= 8 { result.append("Long proof at ≥26 °C – high risk of over-proofing.") }
        if !recipe.isDetroit && (recipe.doughWeight < 200 || recipe.doughWeight > 300) { result.append("Typical ball weight is 230–280 g for a 30–33 cm pizza.") }
        if recipe.isDetroit && recipe.waterRatio < 65 { result.append("Detroit dough is usually \(68)–\(75)% hydration for an airy crumb.") }
        if recipe.isDetroit && recipe.oilRatio == 0 { result.append("Add ~\(2)% oil for Detroit – and oil the pan generously.") }
        if recipe.effectiveCoolTime() > 72 { result.append("More than 72 h in the fridge – gluten may break down.") }
        return result
    }

    var body: some View {
        if !warnings.isEmpty {
            Section("Check") {
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, text in
                    Label(text, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

#Preview {
    let recipeSetupData = RecipeSetupData(doughBallsCount: 4, doughWeight: 300, waterRatio: 65, saltRatio: 3, yeastSelection: 1, fridgeTimeMode: "MANUAL", roomTemp: 27, roomTime: 12, coolTemp: 4, coolTime: 12, dateSelection: Date())
    let path = Binding.constant(NavigationPath())
    DoughResultView(recipeSetupData: recipeSetupData, path: path, isShowingNewRecipeView: .constant(false))
        .padding(.horizontal)
}
