//
//  MenuSettingsView.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

/// Untermenü „Pizzen & Mengen“: auswählbare Pizzen, Belag, Zusatzmengen und Einstellungen der Gästeseite (ändert sich selten)
struct MenuSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuPizza.sortIndex) private var pizzas: [MenuPizza]
    @AppStorage(AppKeys.fbProject) private var project = GuestFirebaseDefaults.project
    @AppStorage(AppKeys.fbKey) private var apiKey = GuestFirebaseDefaults.apiKey
    @AppStorage(AppKeys.guestPageURL) private var pageURL = GuestFirebaseDefaults.pageURL
    @AppStorage(GuestPush.enabledKey) private var pushEnabled = false
    @AppStorage(GuestPush.statusKey) private var pushStatus = ""
    @State private var editingPizza: MenuPizza?
    @State private var isShowingToppingAmounts = false
    @State private var isShowingNewPizza = false

    private var planPizzas: [MenuPizza] { pizzas.filter { !$0.isGuestCustom } }

    var body: some View {
        List {
            Section {
                ForEach(planPizzas) { pizza in
                    MenuPizzaRow(pizza: pizza, number: nil, showsOrders: false) { editingPizza = pizza }
                }
                .onDelete { offsets in
                    let list = planPizzas
                    offsets.forEach { modelContext.delete(list[$0]) }
                }
                Button("Add pizza", systemImage: "plus") { isShowingNewPizza = true }
            } header: {
                Text("Available pizzas")
            } footer: {
                Text("Toggle the circle to make a pizza available. Tap a pizza to edit its toppings. For each event you can still untick single pizzas.")
            }

            Section {
                Button("Topping amounts for all pizzas", systemImage: "scalemass") { isShowingToppingAmounts = true }
                NavigationLink { ExtraDefaultsEditor() } label: {
                    Label("Extra amounts per pizza", systemImage: "plus.square.on.square")
                }
            } header: {
                Text("Amounts")
            } footer: {
                Text("Change e.g. the tomato sauce once and every pizza gets the new amount. Extra amounts: how much one pizza needs when a guest adds an ingredient.")
            }

            Section {
                Toggle("Push for guest orders", systemImage: "bell.badge", isOn: $pushEnabled)
                    .onChange(of: pushEnabled) { _, on in Task { on ? await GuestPush.enable() : await GuestPush.disable() } }
                if pushEnabled && !pushStatus.isEmpty {
                    Text(pushStatus).font(.caption).foregroundStyle(.secondary)
                }
                // Alles vorbelegt: normalerweise nichts zu tun. Nur für ein eigenes Firebase-Projekt oder eine andere Adresse.
                DisclosureGroup("Advanced (already set up)") {
                    TextField("Firebase project ID", text: $project).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Firebase API key", text: $apiKey).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Guest page address (https://…)", text: $pageURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Reset to defaults", systemImage: "arrow.uturn.backward") {
                        project = GuestFirebaseDefaults.project
                        apiKey = GuestFirebaseDefaults.apiKey
                        pageURL = GuestFirebaseDefaults.pageURL
                    }
                }
            } header: {
                Text("Guest page")
            } footer: {
                Text("A notification on this iPhone when a guest orders, changes or deletes an order. Needs Pizza-Push on the Mac mini (hosting/mac-mini/pizza-push).")
            }
        }
        .navigationTitle("Pizzas & amounts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingToppingAmounts) {
            ToppingAmountsEditor(pizzas: planPizzas)
        }
        .sheet(isPresented: $isShowingNewPizza) {
            NewPizzaSheet(pizzas: planPizzas, nextSortIndex: (pizzas.map(\.sortIndex).max() ?? 0) + 1)
        }
        .onAppear { MenuPizza.addGratedCheeseIfNeeded(into: modelContext) }
        .sheet(item: $editingPizza) { pizza in
            MenuPizzaEditor(pizza: pizza)
        }
    }
}

struct MenuPizzaRow: View {
    @Bindable var pizza: MenuPizza
    var number: Int?
    var showsOrders = true
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if !showsOrders {
                Button {
                    pizza.isOnMenu.toggle()
                } label: {
                    Image(systemName: pizza.isOnMenu ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(pizza.isOnMenu ? .green : .gray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(pizza.name))
                .accessibilityValue(pizza.isOnMenu ? Text("Available") : Text("Not available"))
            }

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text((number.map { "\($0). " } ?? "") + pizza.name).font(.headline)
                    if !pizza.toppingsText.isEmpty {
                        Text(pizza.toppingsText).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if showsOrders {
                Stepper("\(pizza.orderCount)", value: $pizza.orderCount, in: 0...99)
                    .fixedSize()
                    .monospacedDigit()
            }
        }
        .opacity(pizza.isOnMenu || showsOrders ? 1 : 0.5)
    }
}

/// Belagmengen für alle Pizzen auf einmal: Jede Zutat steht einmal da, eine Änderung gilt für jede Pizza mit dieser Zutat.
struct ToppingAmountsEditor: View {
    @Environment(\.dismiss) private var dismiss
    var pizzas: [MenuPizza]

    private struct ToppingGroup: Identifiable {
        var id: String { key }
        var key: String
        var name: String
        var unit: String
        var count: Int
    }

    private static func key(_ topping: Topping) -> String {
        "\(topping.name.trimmingCharacters(in: .whitespaces).lowercased())|\(topping.unit)"
    }

    private var groups: [ToppingGroup] {
        var result: [ToppingGroup] = []
        for topping in pizzas.flatMap(\.toppings) where !topping.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let key = Self.key(topping)
            if let index = result.firstIndex(where: { $0.key == key }) {
                result[index].count += 1
            } else {
                result.append(ToppingGroup(key: key, name: topping.name, unit: topping.unit, count: 1))
            }
        }
        return result
    }

    private func amounts(of key: String) -> [Double] {
        pizzas.flatMap(\.toppings).filter { Self.key($0) == key }.map(\.amount)
    }

    /// Häufigste Menge anzeigen; beim Ändern bekommen alle Pizzen mit dieser Zutat die neue Menge
    private func binding(for key: String) -> Binding<Double> {
        Binding {
            let values = amounts(of: key)
            let counts = Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
            return counts.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }?.key ?? 0
        } set: { newValue in
            for pizza in pizzas {
                var toppings = pizza.toppings
                var changed = false
                for index in toppings.indices where Self.key(toppings[index]) == key && toppings[index].amount != newValue {
                    toppings[index].amount = newValue
                    changed = true
                }
                if changed { pizza.toppings = toppings }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(groups) { group in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(group.name)
                                if Set(amounts(of: group.key)).count > 1 {
                                    Text("On \(group.count) pizzas, amounts differ")
                                        .font(.caption).foregroundStyle(.orange)
                                } else {
                                    Text("On \(group.count) pizzas")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            AmountField(value: binding(for: group.key))
                            Text(LocalizedStringKey(group.unit)).foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Amount per pizza. A change applies to every pizza with this topping; you can still change single pizzas afterwards.")
                }
            }
            .navigationTitle("Topping amounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

/// Neue Pizza: alle bisherigen Zutaten zum Ankreuzen mit Menge, optional eine andere Pizza als Vorlage
struct NewPizzaSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var pizzas: [MenuPizza]
    var nextSortIndex: Int

    private struct Choice: Identifiable {
        var id = UUID()
        var key: String
        var name: String
        var unit: String
        var amount: Double
        var selected = false
        /// Selbst hinzugefügte Zutat (Name und Einheit frei wählbar)
        var isCustom: Bool { key.hasPrefix("custom-") }
    }

    @State private var name = ""
    @State private var template: PersistentIdentifier?
    @State private var choices: [Choice] = []
    @State private var didLoad = false

    private static func key(_ name: String, _ unit: String) -> String {
        "\(name.trimmingCharacters(in: .whitespaces).lowercased())|\(unit)"
    }

    /// Jede bisher verwendete Zutat einmal, mit der häufigsten Menge
    private func loadChoices() {
        var amounts: [String: [Double]] = [:]
        var result: [Choice] = []
        for topping in pizzas.flatMap(\.toppings) where !topping.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let key = Self.key(topping.name, topping.unit)
            if amounts[key] == nil {
                result.append(Choice(key: key, name: topping.name, unit: topping.unit, amount: topping.amount))
            }
            amounts[key, default: []].append(topping.amount)
        }
        for index in result.indices {
            let counts = Dictionary((amounts[result[index].key] ?? []).map { ($0, 1) }, uniquingKeysWith: +)
            if let common = counts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value })?.key {
                result[index].amount = common
            }
        }
        // Reibekäse gehört auf jede Pizza: vorhandenen Eintrag (egal wie er heißt) vorauswählen, nur wenn keiner da ist neu anbieten
        if let index = result.firstIndex(where: { MenuPizza.isGratedCheese($0.name) }) {
            result[index].selected = true
        } else {
            let cheese = MenuPizza.gratedCheese
            result.append(Choice(key: Self.key(cheese.name, cheese.unit), name: cheese.name, unit: cheese.unit,
                                 amount: cheese.amount, selected: true))
        }
        // Reibekäse und Mozzarella ganz oben, der Rest alphabetisch
        choices = result.sorted { a, b in
            let rankA = Self.rank(a.name), rankB = Self.rank(b.name)
            if rankA != rankB { return rankA < rankB }
            return Self.displayName(a.name).localizedStandardCompare(Self.displayName(b.name)) == .orderedAscending
        }
    }

    private static func rank(_ name: String) -> Int {
        if MenuPizza.isGratedCheese(name) { return 0 }
        if displayName(name).lowercased().contains("mozzarella") { return 1 }
        return 2
    }

    /// Angezeigter Name (Belag-Namen sind teils englische Schlüssel, z. B. „Cooked ham“ → „Schinken“)
    private static func displayName(_ name: String) -> String {
        Bundle.main.localizedString(forKey: name, value: nil, table: nil)
    }

    /// Belag der Vorlage übernehmen: genau diese Zutaten mit ihren Mengen anhaken (Liste bleibt alphabetisch)
    private func apply(template id: PersistentIdentifier?) {
        guard let pizza = pizzas.first(where: { $0.persistentModelID == id }) else { return }
        for index in choices.indices { choices[index].selected = false }
        for topping in pizza.toppings where !topping.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let key = Self.key(topping.name, topping.unit)
            if let index = choices.firstIndex(where: { $0.key == key }) {
                choices[index].amount = topping.amount
                choices[index].selected = true
            }
        }
    }

    private var selectedCount: Int { choices.filter(\.selected).count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Template", selection: $template) {
                        Text("None").tag(PersistentIdentifier?.none)
                        ForEach(pizzas) { pizza in
                            Text(pizza.name).tag(Optional(pizza.persistentModelID))
                        }
                    }
                } footer: {
                    Text("With a template, its toppings and amounts are ticked. You can change everything.")
                }

                Section {
                    ForEach($choices) { $choice in
                        HStack {
                            Button {
                                choice.selected.toggle()
                            } label: {
                                Image(systemName: choice.selected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(choice.selected ? .green : .gray)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(choice.name))
                            .accessibilityAddTraits(choice.selected ? .isSelected : [])
                            if choice.isCustom {
                                TextField("Topping", text: $choice.name)
                            } else {
                                Text(LocalizedStringKey(choice.name))
                                    .foregroundStyle(choice.selected ? .primary : .secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture { choice.selected.toggle() }
                            }
                            AmountField(value: $choice.amount)
                            if choice.isCustom {
                                Picker("Unit", selection: $choice.unit) {
                                    ForEach(["g", "ml", "pcs", "tsp"], id: \.self) { unit in
                                        Text(LocalizedStringKey(unit)).tag(unit)
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()
                            } else {
                                Text(LocalizedStringKey(choice.unit)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("Other topping", systemImage: "plus") {
                        choices.append(Choice(key: "custom-\(UUID().uuidString)", name: "", unit: "g", amount: 50, selected: true))
                    }
                } header: {
                    Text("Toppings per pizza")
                } footer: {
                    Text("All toppings of your pizzas. Tick what goes on this pizza and adjust the amount.")
                }
            }
            .navigationTitle("New pizza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                loadChoices()
            }
            .onChange(of: template) { _, id in apply(template: id) }
        }
    }

    private func create() {
        let toppings = choices
            .filter { $0.selected && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { Topping(name: $0.name.trimmingCharacters(in: .whitespaces), amount: $0.amount, unit: $0.unit) }
        let source = pizzas.first { $0.persistentModelID == template }
        let pizza = MenuPizza(name: name.trimmingCharacters(in: .whitespaces), toppings: toppings,
                              sortIndex: nextSortIndex, isDetroit: source?.isDetroit ?? false)
        modelContext.insert(pizza)
        try? modelContext.save()
        dismiss()
    }
}

struct MenuPizzaEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var pizza: MenuPizza

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $pizza.name)
                    TextField("Short description (optional)", text: $pizza.info)
                    Toggle("Detroit (pan)", isOn: $pizza.isDetroit)
                }
                Section {
                    ForEach($pizza.toppings) { $topping in
                        HStack {
                            TextField("Topping", text: $topping.name)
                            AmountField(value: $topping.amount)
                            Picker("Unit", selection: $topping.unit) {
                                ForEach(["g", "ml", "pcs", "tsp"], id: \.self) { unit in
                                    Text(LocalizedStringKey(unit)).tag(unit)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                    .onDelete { pizza.toppings.remove(atOffsets: $0) }
                    .onMove { pizza.toppings.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add topping", systemImage: "plus") {
                        pizza.toppings.append(Topping(name: "", amount: 50))
                    }
                } header: {
                    Text("Toppings per pizza")
                }
            }
            .navigationTitle(pizza.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
