//
//  MenuView.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

/// Speisekarte für den Pizzaabend: an Gäste schicken, Bestellungen eintragen, Zutaten berechnen.
struct MenuView: View {
    enum Mode { case plan, orders }
    var mode: Mode = .plan
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuPizza.sortIndex) private var pizzas: [MenuPizza]
    @AppStorage("menuTitle") private var menuTitle = ""
    @AppStorage("menuDate") private var menuDate: Double = Date().timeIntervalSince1970
    @State private var editingPizza: MenuPizza?
    @State private var addedToShopping = false
    @State private var pdfURL: URL?
    @State private var isShowingGuestLink = false

    private var onMenu: [MenuPizza] { pizzas.filter(\.isOnMenu) }
    private var totalOrders: Int { onMenu.reduce(0) { $0 + $1.orderCount } }
    private var roundCount: Int { onMenu.filter { !$0.isDetroit }.reduce(0) { $0 + $1.orderCount } }
    private var detroitCount: Int { onMenu.filter(\.isDetroit).reduce(0) { $0 + $1.orderCount } }

    var body: some View {
        List {
            if mode == .plan {
            Section {
                TextField("Pizza night", text: $menuTitle)
                DatePicker("Date", selection: dateBinding, displayedComponents: [.date, .hourAndMinute])
            } header: {
                Text("Event")
            }

            Section {
                ShareLink(item: shareText, subject: Text(title)) {
                    Label("Send menu as text (WhatsApp, Messages …)", systemImage: "square.and.arrow.up")
                }
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Send menu as PDF", systemImage: "doc.richtext")
                    }
                }
                Button("Guest link: guests order online", systemImage: "person.2.badge.plus") {
                    isShowingGuestLink = true
                }
            } footer: {
                Text("Your guests reply with the number and count, e.g. “1×2, 3×1”. Enter the orders in the “Orders” tab.")
            }
            }

            if mode == .plan {
            Section {
                ForEach(pizzas) { pizza in
                    MenuPizzaRow(pizza: pizza, number: number(of: pizza), showsOrders: false) { editingPizza = pizza }
                }
                .onDelete { offsets in offsets.forEach { modelContext.delete(pizzas[$0]) } }
                Button("Add pizza", systemImage: "plus") {
                    let pizza = MenuPizza(name: String(localized: "New pizza"), sortIndex: (pizzas.map(\.sortIndex).max() ?? 0) + 1)
                    modelContext.insert(pizza)
                    editingPizza = pizza
                }
            } header: {
                Text("Pizzas")
            } footer: {
                Text("Toggle the circle to put a pizza on or off the menu. Tap a pizza to edit its toppings.")
            }
            }

            if mode == .orders {
                Section {
                    ForEach(onMenu) { pizza in
                        MenuPizzaRow(pizza: pizza, number: number(of: pizza), showsOrders: true) { editingPizza = pizza }
                    }
                    if onMenu.isEmpty {
                        Text("No pizzas on the menu yet – pick some in “Plan”.").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Orders")
                }
            }

            if mode == .orders && totalOrders > 0 {
                Section {
                    LabeledContent("Pizzas ordered", value: "\(totalOrders)")
                    ForEach(aggregatedToppings, id: \.key) { item in
                        LabeledContent(item.name, value: MenuPizza.formatted(item.amount, unit: item.unit))
                    }
                    Button {
                        ShoppingItem.add(aggregatedToppings.map { ($0.name, MenuPizza.formatted($0.amount, unit: $0.unit)) },
                                         source: title, to: modelContext)
                        addedToShopping = true
                    } label: {
                        Label(addedToShopping ? "Added to shopping list" : "Add toppings to shopping list",
                              systemImage: addedToShopping ? "checkmark" : "cart.badge.plus")
                    }
                    Button("Reset orders", systemImage: "arrow.counterclockwise", role: .destructive) {
                        pizzas.forEach { $0.orderCount = 0; $0.removedToppings = [:] }
                        addedToShopping = false
                    }
                } header: {
                    Text("Needed toppings")
                } footer: {
                    Text("Dough: \(roundCount) dough balls, \(detroitCount) Detroit pans – create the dough recipe with the + button.")
                }
            }
        }
        .sheet(isPresented: $isShowingGuestLink) {
            GuestLinkSheet(title: title, date: date, pizzas: onMenu)
        }
        .sheet(item: $editingPizza) { pizza in
            MenuPizzaEditor(pizza: pizza)
        }
        .task(id: shareText) { pdfURL = MenuPDF.render(title: title, date: date, pizzas: onMenu) }
        .onAppear { MenuPizza.seedIfNeeded(into: modelContext) }
    }

    private var date: Date { Date(timeIntervalSince1970: menuDate) }
    private var dateBinding: Binding<Date> {
        Binding { date } set: { menuDate = $0.timeIntervalSince1970 }
    }
    private var title: String { menuTitle.isEmpty ? String(localized: "Pizza night") : menuTitle }

    private func number(of pizza: MenuPizza) -> Int? {
        onMenu.firstIndex { $0.persistentModelID == pizza.persistentModelID }.map { $0 + 1 }
    }

    /// Text für WhatsApp & Co.
    private var shareText: String {
        var lines = ["🍕 \(title) – \(date.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))", ""]
        for (index, pizza) in onMenu.enumerated() {
            lines.append("\(index + 1). \(pizza.name)" + (pizza.info.isEmpty ? "" : " (\(pizza.info))"))
            if !pizza.toppingsText.isEmpty { lines.append("    \(pizza.toppingsText)") }
        }
        lines.append("")
        lines.append(String(localized: "Please reply with number × count, e.g. “1×2, 3×1”. Thanks!"))
        return lines.joined(separator: "\n")
    }

    /// Belag aller Bestellungen zusammengerechnet (gleicher Name + Einheit)
    private var aggregatedToppings: [(key: String, name: String, amount: Double, unit: String)] {
        var totals: [String: (name: String, amount: Double, unit: String)] = [:]
        var order: [String] = []
        for pizza in onMenu where pizza.orderCount > 0 {
            for topping in pizza.toppings {
                let key = "\(topping.name.lowercased())|\(topping.unit)"
                if totals[key] == nil { order.append(key) }
                let count = max(0, pizza.orderCount - (pizza.removedToppings[topping.name] ?? 0))
                if count > 0 { totals[key, default: (topping.name, 0, topping.unit)].amount += topping.amount * Double(count) }
            }
        }
        return order.compactMap { key -> (key: String, name: String, amount: Double, unit: String)? in
            guard let item = totals[key] else { return nil }
            return (key, item.name, item.amount, item.unit)
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
                            TextField("Amount", value: $topping.amount, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
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

/// Speisekarte als hübsches PDF zum Verschicken
enum MenuPDF {
    @MainActor
    static func render(title: String, date: Date, pizzas: [MenuPizza]) -> URL? {
        let card = MenuCardView(title: title, date: date,
                                items: pizzas.map { ($0.name, $0.info, $0.toppingsText) })
            .frame(width: 595)          // A4-Breite in Punkt
        let renderer = ImageRenderer(content: card)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(String(localized: "Menu")).pdf")
        var ok = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: CGSize(width: 595, height: max(size.height, 842)))
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            // oben ausrichten
            context.translateBy(x: 0, y: box.height - size.height)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}

struct MenuCardView: View {
    var title: String
    var date: Date
    var items: [(name: String, info: String, toppings: String)]

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("🍕").font(.system(size: 48))
                Text(title).font(.system(size: 34, weight: .bold, design: .serif))
                Text(date, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                    .font(.system(size: 16, design: .serif)).foregroundStyle(.secondary)
            }
            Rectangle().fill(Color.red.opacity(0.6)).frame(width: 120, height: 2)
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundStyle(.red)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name).font(.system(size: 20, weight: .semibold, design: .serif))
                            if !item.info.isEmpty {
                                Text(item.info).font(.system(size: 13, design: .serif)).italic().foregroundStyle(.secondary)
                            }
                            if !item.toppings.isEmpty {
                                Text(item.toppings).font(.system(size: 14, design: .serif))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Please reply with number × count, e.g. “1×2, 3×1”. Thanks!")
                .font(.system(size: 13, design: .serif)).italic().foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(48)
        .background(Color(red: 1, green: 0.98, blue: 0.94))
        .environment(\.colorScheme, .light)
    }
}

/// Tab "Menü": Speisekarte und Einkaufsliste
struct MenuAndShoppingView: View {
    enum Page: Hashable { case plan, orders, shopping }
    @State private var page: Page = .plan

    var body: some View {
        VStack(spacing: 0) {
            Picker("Page", selection: $page) {
                Text("Plan").tag(Page.plan)
                Text("Orders").tag(Page.orders)
                Text("Shopping list").tag(Page.shopping)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 6)
            switch page {
            case .plan: MenuView(mode: .plan)
            case .orders: MenuView(mode: .orders)
            case .shopping: ShoppingListView()
            }
        }
    }
}

#Preview {
    NavigationStack { MenuAndShoppingView() }
}
