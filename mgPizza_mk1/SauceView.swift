//
//  SauceView.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

/// Liste aller Saucenrezepte.
struct SauceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SauceRecipe.createdAt, order: .reverse) private var sauces: [SauceRecipe]

    var body: some View {
        List {
            Button("New Sauce", systemImage: "plus") {
                let sauce = SauceRecipe()
                modelContext.insert(sauce)
            }
            if sauces.isEmpty {
                ContentUnavailableView("No sauces yet", systemImage: "drop",
                                       description: Text("Tap “New Sauce” to start with a classic Neapolitan base."))
            }
            ForEach(sauces) { sauce in
                NavigationLink {
                    SauceDetailView(sauce: sauce)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(sauce.displayName).font(.headline)
                            Text("\(Int(sauce.pizzaCount)) pizzas × \(Int(sauce.gramsPerPizza)) g")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StarRatingView(rating: .constant(sauce.rating), size: 12)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button("Duplicate", systemImage: "doc.on.doc") {
                        let copy = SauceRecipe(name: sauce.name, pizzaCount: sauce.pizzaCount,
                                               gramsPerPizza: sauce.gramsPerPizza, tomatoName: sauce.tomatoName,
                                               ingredients: sauce.ingredients.map { SauceIngredient(name: $0.name, percent: $0.percent, unit: $0.unit) })
                        modelContext.insert(copy)
                    }
                    .tint(.blue)
                }
            }
            .onDelete { offsets in
                offsets.forEach { modelContext.delete(sauces[$0]) }
            }
        }
    }
}

/// Rechner + Editor für eine Sauce. Alle Zutaten sind in % der Tomatenmenge angegeben.
struct SauceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var sauce: SauceRecipe
    @State private var isShowingShoppingPicker = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $sauce.name)
                Stepper("Pizzas: \(Int(sauce.pizzaCount))", value: $sauce.pizzaCount, in: 1...60)
                VStack(alignment: .leading) {
                    Text("Sauce per Pizza: \(Int(sauce.gramsPerPizza)) g")
                    Slider(value: $sauce.gramsPerPizza, in: 40...150, step: 5)
                }
            }

            Section(header: Text("Result")) {
                HStack {
                    Text(sauce.tomatoName)
                    Spacer()
                    Text("\(sauce.tomatoWeight, specifier: "%.0f") g").bold()
                }
                ForEach(sauce.ingredients.filter { $0.percent > 0 }) { ingredient in
                    HStack {
                        Text(LocalizedStringKey(ingredient.name))
                        Spacer()
                        Text(sauce.formattedAmount(of: ingredient)).bold()
                    }
                }
            }

            SauceTipsSection(sauce: sauce)

            Section(header: Text("Ingredients"),
                    footer: Text("% = share of the tomato weight. g / ml / pcs / tsp = amount for all \(Int(sauce.pizzaCount)) pizzas, scales when you change the pizza count. Tip: Neapolitan style uses only crushed raw tomatoes + ~1.5–2% salt; basil and oil go on the pizza.")) {
                TextField("Tomatoes", text: $sauce.tomatoName)
                ForEach($sauce.ingredients) { $ingredient in
                    HStack {
                        TextField("Ingredient", text: $ingredient.name)
                        AmountField(value: amountBinding($ingredient), width: 70)
                        Picker("Unit", selection: $ingredient.unit) {
                            ForEach(SauceUnit.allCases) { unit in
                                Text(LocalizedStringKey(unit.rawValue)).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                .onDelete { sauce.ingredients.remove(atOffsets: $0) }
                Button("Add ingredient", systemImage: "plus") {
                    sauce.ingredients.append(SauceIngredient(name: "", percent: 1.0))
                }
            }

            Section {
                Button("Add to shopping list", systemImage: "cart.badge.plus") {
                    isShowingShoppingPicker = true
                }
            }

            Section(header: Text("Feedback")) {
                StarRatingView(rating: $sauce.rating, size: 28, isEditable: true)
                    .frame(maxWidth: .infinity)
                TextField("Notes", text: $sauce.notes, axis: .vertical)
                    .lineLimit(4...12)
            }
        }
        .navigationTitle(sauce.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingShoppingPicker) {
            ShoppingPickerSheet(items: sauce.shoppingItems, source: sauce.displayName)
        }
    }

    /// % wird direkt bearbeitet; g / ml / Stück werden als Gesamtmenge angezeigt und pro Pizza gespeichert.
    private func amountBinding(_ ingredient: Binding<SauceIngredient>) -> Binding<Double> {
        Binding {
            let item = ingredient.wrappedValue
            return item.unit == .percent ? item.percent : item.percent * sauce.pizzaCount
        } set: { newValue in
            let value = max(0, newValue)
            ingredient.wrappedValue.percent = ingredient.wrappedValue.unit == .percent ? value : value / max(sauce.pizzaCount, 1)
        }
    }
}

#Preview {
    NavigationStack { SauceDetailView(sauce: SauceRecipe()) }
}

/// Hinweise zu einzelnen Zutaten (z. B. Kürbiskernöl erst nach dem Kochen)
struct SauceTipsSection: View {
    var sauce: SauceRecipe

    private static let rules: [(keywords: [String], tip: LocalizedStringKey, icon: String)] = [
        (["kürbiskern", "pumpkin"], "Pumpkin seed oil: stir in only after cooking – heat destroys its aroma (smoke point ~120 °C).", "drop.fill"),
        (["basilikum", "basil"], "Basil: add fresh at the end or onto the pizza – cooking makes it taste flat.", "leaf.fill"),
        (["balsamico", "balsamic"], "Balsamic: add at the end, a little goes a long way.", "drop"),
        (["oregano"], "Dried oregano: cook it briefly with the sauce or rub it between your fingers before adding.", "leaf"),
        (["knoblauch", "garlic"], "Garlic: sauté gently only – brown garlic turns bitter.", "flame"),
    ]

    private var tips: [(tip: LocalizedStringKey, icon: String)] {
        let names = ([sauce.tomatoName] + sauce.ingredients.filter { $0.percent > 0 }.map(\.name) + [sauce.notes])
            .joined(separator: " ").lowercased()
        return Self.rules.filter { rule in rule.keywords.contains(where: names.contains) }.map { ($0.tip, $0.icon) }
    }

    var body: some View {
        if !tips.isEmpty {
            Section("Tips") {
                ForEach(Array(tips.enumerated()), id: \.offset) { _, item in
                    Label(item.tip, systemImage: item.icon)
                        .font(.callout)
                }
            }
        }
    }
}
