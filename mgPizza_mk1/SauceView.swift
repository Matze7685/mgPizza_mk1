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
    @State private var addedToShopping = false

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

            Section(header: Text("Result"), footer: Text("Total: \(sauce.totalWeight, specifier: "%.0f") g")) {
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

            Section(header: Text("Ingredients"),
                    footer: Text("% = share of the tomato weight. g / ml / pcs = amount for all \(Int(sauce.pizzaCount)) pizzas, scales when you change the pizza count. Tip: Neapolitan style uses only crushed raw tomatoes + ~1.5–2% salt; basil and oil go on the pizza.")) {
                TextField("Tomatoes", text: $sauce.tomatoName)
                ForEach($sauce.ingredients) { $ingredient in
                    HStack {
                        TextField("Ingredient", text: $ingredient.name)
                        TextField("Amount", value: amountBinding($ingredient), format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
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
                Button {
                    ShoppingItem.add(sauce.shoppingItems, source: sauce.displayName, to: modelContext)
                    addedToShopping = true
                } label: {
                    Label(addedToShopping ? "Added to shopping list" : "Add to shopping list",
                          systemImage: addedToShopping ? "checkmark" : "cart.badge.plus")
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
