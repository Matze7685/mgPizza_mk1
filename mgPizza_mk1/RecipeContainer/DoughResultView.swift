//
//  DoughResultView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import SwiftUI

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
    /// Wert, zu dem eine Warnung gehört (für die Anzeige direkt beim Regler)
    enum Field { case water, salt, ballWeight, oil, room, fridge }

    var recipe: RecipeSetupData

    static func warnings(for recipe: RecipeSetupData) -> [(field: Field, text: LocalizedStringKey)] {
        var result: [(field: Field, text: LocalizedStringKey)] = []
        if recipe.waterRatio < 58 { result.append((.water, "Hydration below \(58)% gives a dry, dense crust.")) }
        if recipe.waterRatio > 75 { result.append((.water, "Hydration above \(75)% is hard to handle – use strong flour (W300+).")) }
        if recipe.saltRatio < 2.2 { result.append((.salt, "Salt below \(2.2, specifier: "%.1f")% tastes flat and weakens the gluten.")) }
        if recipe.saltRatio > 3.2 { result.append((.salt, "Salt above \(3.2, specifier: "%.1f")% slows the yeast noticeably.")) }
        if recipe.roomTemp >= 26 && recipe.roomTime >= 8 { result.append((.room, "Long proof at ≥26 °C – high risk of over-proofing.")) }
        if !recipe.isDetroit && (recipe.doughWeight < 200 || recipe.doughWeight > 300) { result.append((.ballWeight, "Typical ball weight is 230–280 g for a 30–33 cm pizza.")) }
        if recipe.isDetroit && recipe.waterRatio < 65 { result.append((.water, "Detroit dough is usually \(68)–\(75)% hydration for an airy crumb.")) }
        if recipe.isDetroit && recipe.oilRatio == 0 { result.append((.oil, "Add ~\(2)% oil for Detroit – and oil the pan generously.")) }
        if recipe.effectiveCoolTime() > 72 { result.append((.fridge, "More than 72 h in the fridge – gluten may break down.")) }
        return result
    }

    var body: some View {
        let warnings = Self.warnings(for: recipe)
        if !warnings.isEmpty {
            Section("Check") {
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                    Label(warning.text, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

/// Warnung direkt beim betroffenen Wert (Teig-Einstellung)
struct InlineDoughWarning: View {
    var recipe: RecipeSetupData
    var field: DoughWarningsSection.Field

    var body: some View {
        ForEach(Array(DoughWarningsSection.warnings(for: recipe).filter { $0.field == field }.enumerated()), id: \.offset) { _, warning in
            Label(warning.text, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
