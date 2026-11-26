//
//  OrdersFoldView.swift
//  mgPizza_mk1
//
//  Geteilte Ansicht für ein faltbares iPhone in der Laptop-Stellung:
//  obere Bildschirmhälfte = aktuelle Pizza groß (Gast, Pizza, Zutaten mit Mengen inkl. Zusatzzutaten),
//  untere Hälfte = Reihenfolge der Zubereitung (verschiebbar, abhaken).
//  Die Teilung liegt genau in der Bildschirmmitte (dort, wo der Knick ist). Auf normalen
//  iPhones funktioniert dieselbe Ansicht einfach als geteilter Bildschirm.
//

import SwiftData
import SwiftUI

/// Eine einzelne Pizza in der Zubereitungs-Reihenfolge (eine Bestellzeile mit Anzahl 2 ergibt zwei Einträge)
struct PrepItem: Codable, Identifiable, Hashable {
    var id: String
    var guest: String
    var pizza: String
    var without: [String] = []
    var extra: [String] = []
    /// Nur bei „Eigene Pizza“: gewählte Zutaten
    var custom: [GuestEvent.Topping]? = nil
    var done = false

    static func == (a: PrepItem, b: PrepItem) -> Bool { a.id == b.id && a.done == b.done }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Zuletzt geladene Gästebestellungen + Zubereitungs-Reihenfolge, pro Abend lokal gespeichert
enum PrepQueueStore {
    private static func ordersKey(_ event: String) -> String { "foldOrders_\(event)" }
    private static func queueKey(_ event: String) -> String { "foldQueue_\(event)" }

    static func orders(event: String) -> [GuestOrder] {
        guard let data = UserDefaults.standard.data(forKey: ordersKey(event)) else { return [] }
        return (try? JSONDecoder().decode([GuestOrder].self, from: data)) ?? []
    }

    static func saveOrders(_ orders: [GuestOrder], event: String) {
        guard !event.isEmpty, let data = try? JSONEncoder().encode(orders) else { return }
        UserDefaults.standard.set(data, forKey: ordersKey(event))
    }

    static func queue(event: String) -> [PrepItem] {
        guard let data = UserDefaults.standard.data(forKey: queueKey(event)) else { return [] }
        return (try? JSONDecoder().decode([PrepItem].self, from: data)) ?? []
    }

    static func saveQueue(_ queue: [PrepItem], event: String) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: queueKey(event))
    }

    /// Einträge aus den Bestellungen bauen; ohne geladene Gästebestellungen aus den Bestellzahlen der Speisekarte
    static func items(orders: [GuestOrder], pizzas: [MenuPizza]) -> [PrepItem] {
        var items: [PrepItem] = []
        if orders.isEmpty {
            for pizza in pizzas where pizza.isOnMenu && pizza.orderCount > 0 {
                // Extras pro Sorte (Anlass mit festen Mengen)
                let extra = pizza.guestExtras.filter { $0.value > 0 }.keys.sorted()
                for n in 0..<pizza.orderCount {
                    items.append(PrepItem(id: "menu|\(pizza.name)|\(n)", guest: "", pizza: pizza.name, extra: extra))
                }
            }
            return items
        }
        for order in orders {
            for (index, line) in order.lines.enumerated() where line.count > 0 {
                for n in 0..<line.count {
                    items.append(PrepItem(id: "\(order.guest)|\(index)|\(line.name)|\(n)", guest: order.guest, pizza: line.name,
                                          without: line.without, extra: line.extra ?? [], custom: line.custom))
                }
            }
        }
        return items
    }

    /// Neue Einträge in die vorhandene Reihenfolge einfügen: bekannte behalten Platz und Haken, neue kommen ans Ende
    static func merge(_ fresh: [PrepItem], into old: [PrepItem]) -> [PrepItem] {
        let freshByID = Dictionary(fresh.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var result: [PrepItem] = old.compactMap { item in
            guard var updated = freshByID[item.id] else { return nil }
            updated.done = item.done
            return updated
        }
        let known = Set(result.map(\.id))
        result += fresh.filter { !known.contains($0.id) }
        return result
    }
}

struct OrdersFoldView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuPizza.sortIndex) private var pizzas: [MenuPizza]

    @AppStorage("fbProject") private var project = GuestFirebaseDefaults.project
    @AppStorage("fbKey") private var apiKey = GuestFirebaseDefaults.apiKey
    @AppStorage("menuEventID") private var eventID = ""
    @AppStorage("menuTitle") private var menuTitle = ""
    /// Anlass mit festen Mengen: keine Gästebestellungen abholen, nur die Stückzahlen pro Sorte
    @AppStorage("menuFixedMode") private var isFixed = false
    /// Abstand für den Knick in der Mitte (Punkte); dort steht kein Inhalt
    @AppStorage("foldHingeGap") private var hingeGap: Double = 24
    /// Halbbildschirme tauschen (falls das Gerät andersherum gehalten wird)
    @AppStorage("foldSwapHalves") private var swapHalves = false
    /// Spalten für die Zutaten oben (Einstellungen)
    @AppStorage("foldColumns") private var foldColumns = 2
    /// Nächste Pizza inkl. Zutaten neben der aktuellen anzeigen (Einstellungen)
    @AppStorage("foldShowNext") private var showNextPizza = false

    @State private var queue: [PrepItem] = []
    /// Oben angezeigte Pizza; ohne Auswahl die erste noch nicht fertige
    @State private var selectedID: String?
    @State private var status = ""
    @State private var isBusy = false
    @State private var isSorting = false

    private var current: PrepItem? {
        queue.first { $0.id == selectedID } ?? queue.first { !$0.done }
    }
    private var next: PrepItem? {
        guard let current, let index = queue.firstIndex(of: current) else { return nil }
        return queue[(index + 1)...].first { !$0.done }
    }
    private var doneCount: Int { queue.filter(\.done).count }
    private var title: String { menuTitle.isEmpty ? String(localized: "Pizza night") : menuTitle }

    var body: some View {
        GeometryReader { geo in
            // Gesamthöhe inkl. Statusleiste/Home-Indikator, damit die Teilung genau auf dem Knick liegt
            let full = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let half = max(0, (full - hingeGap) / 2)
            let firstHeight = max(0, half - geo.safeAreaInsets.top)
            let secondHeight = max(0, half - geo.safeAreaInsets.bottom)
            VStack(spacing: 0) {
                Group {
                    if swapHalves { controls } else { overview }
                }
                .frame(height: firstHeight)
                .clipped()

                hinge.frame(height: hingeGap)

                Group {
                    if swapHalves { overview } else { controls }
                }
                .frame(height: secondHeight)
                .clipped()
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true     // Display bleibt beim Backen an
            rebuild(orders: isFixed ? [] : PrepQueueStore.orders(event: eventID))
            if !eventID.isEmpty && !isFixed { Task { await fetch() } }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: queue) { _, new in PrepQueueStore.saveQueue(new, event: eventID) }
    }

    // MARK: - Knick

    private var hinge: some View {
        ZStack {
            Color.black.opacity(0.06)
            Capsule().fill(.quaternary).frame(width: 44, height: 4)
        }
    }

    // MARK: - Obere Hälfte: aktuelle Pizza mit Zutaten

    private var overview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(title).font(.headline).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("\(doneCount)/\(queue.count)")
                    .font(.title2.bold()).monospacedDigit()
                    .foregroundStyle(!queue.isEmpty && doneCount == queue.count ? Color.green : Color.primary)
                Button {
                    finishCurrent()
                } label: {
                    Label("Next pizza", systemImage: "chevron.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(current == nil || current?.done == true)
            }

            if let item = current {
                if showNextPizza {
                    // Feste Breiten statt freier Verteilung, damit beide Hälften sicher sichtbar sind
                    GeometryReader { geo in
                        HStack(alignment: .top, spacing: 12) {
                            pizzaPanel(item, scale: 0.8)
                                .frame(width: max(0, (geo.size.width - 25) * 0.55))
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Next").font(.caption.weight(.semibold)).textCase(.uppercase).foregroundStyle(.secondary)
                                if let next {
                                    pizzaPanel(next, scale: 0.7)
                                } else {
                                    Text("No more pizzas").font(.headline).foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                            .frame(width: max(0, (geo.size.width - 25) * 0.45), alignment: .leading)
                            .opacity(0.6)
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                } else {
                    pizzaPanel(item, scale: 1)
                    if let next {
                        Text("Next: \(next.guest.isEmpty ? pizzaTitle(next) : "\(next.guest) – \(pizzaTitle(next))")")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else {
                Spacer()
                (queue.isEmpty ? Text("No orders yet.") : Text("All pizzas done! 🍕"))
                    .font(.title2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    /// Gast, Pizza und Zutaten einer Pizza
    private func pizzaPanel(_ item: PrepItem, scale: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    if !item.guest.isEmpty {
                        Text(item.guest).font(.system(size: 34 * scale, weight: .bold, design: .rounded))
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Text(pizzaTitle(item)).font(.system(size: 22 * scale, weight: .semibold))
                        .foregroundStyle(item.guest.isEmpty ? .primary : .secondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                ingredientGrid(item, scale: scale)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .opacity(item.done ? 0.5 : 1)
    }

    private func pizzaTitle(_ item: PrepItem) -> String {
        item.custom == nil ? item.pizza : String(localized: "Custom pizza")
    }

    private enum IngredientKind { case normal, extra, without }

    private struct Ingredient {
        var name: String
        var kind: IngredientKind
        var amount: String? = nil
    }

    /// Zutaten ohne Mengenangaben: normale, Zusatzzutaten (grün) und abgewählte (rot)
    private func ingredients(_ item: PrepItem) -> [Ingredient] {
        let base: [String]
        if let custom = item.custom {
            base = custom.map(\.name)
        } else {
            let toppings = pizzas.first { $0.name == item.pizza }?.toppings ?? []
            base = toppings.map(\.name).filter { !item.without.contains($0) }
        }
        var list = base.map { Ingredient(name: $0, kind: .normal) }
        // Zusatzzutaten nur als Name (grün), ohne Mengenangabe
        list += item.extra.map { Ingredient(name: $0, kind: .extra) }
        list += item.without.map { Ingredient(name: $0, kind: .without) }
        return list
    }

    /// Zutaten in 2 oder 3 Spalten (Einstellung); Schrift umso größer, je weniger Zutaten es sind
    /// Grundzutaten, die immer oben untereinander stehen (Reihenfolge = Reihenfolge beim Belegen)
    private static let baseEmojis = ["🍅", "🧀", "⚪️"]

    /// Index der Grundzutat (0 Tomatensauce, 1 Reibekäse, 2 Mozzarella) oder nil
    private static func baseLayer(of ingredient: Ingredient) -> Int? {
        guard ingredient.kind != .without else { return nil }
        let name = Bundle.main.localizedString(forKey: ingredient.name, value: nil, table: nil).lowercased()
        if name.contains("tomatensauce") || name.contains("tomato sauce") || name.contains("sugo") { return 0 }
        if MenuPizza.isGratedCheese(ingredient.name) { return 1 }
        if name.contains("mozzarella") { return 2 }
        return nil
    }

    /// Oben untereinander: Tomatensauce, Reibekäse, Mozzarella (mit Emoji); darunter die übrigen Zutaten
    /// in 2 oder 3 Spalten (Einstellung). Schrift umso größer, je weniger Zutaten es sind
    private func ingredientGrid(_ item: PrepItem, scale: CGFloat) -> some View {
        let all = ingredients(item)
        let base = all.enumerated()
            .compactMap { entry in Self.baseLayer(of: entry.element).map { (layer: $0, index: entry.offset) } }
            .sorted { ($0.layer, $0.index) < ($1.layer, $1.index) }
        let baseIndices = Set(base.map(\.index))
        let rest = all.indices.filter { !baseIndices.contains($0) }.map { all[$0] }
        let columns = max(1, min(3, foldColumns))
        let rows = base.count + (rest.count + columns - 1) / columns
        let size: CGFloat = (rows <= 4 ? 30 : rows <= 6 ? 24 : rows <= 8 ? 20 : 17) * scale
        return VStack(alignment: .leading, spacing: 8) {
            if !base.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(base, id: \.index) { entry in
                        let ingredient = all[entry.index]
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(Self.baseEmojis[entry.layer])
                            Text(LocalizedStringKey(ingredient.name)).bold()
                                .foregroundStyle(ingredient.kind == .extra ? Color.green : Color.primary)
                            if ingredient.kind == .extra {
                                Text("extra").font(.system(size: size * 0.55).weight(.semibold)).foregroundStyle(.green)
                                if let amount = ingredient.amount {
                                    Text(amount).font(.system(size: size * 0.55)).monospacedDigit().foregroundStyle(.secondary)
                                }
                            }
                        }
                        .font(.system(size: size))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    }
                }
                if !rest.isEmpty { Divider() }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .leading), count: columns),
                      alignment: .leading, spacing: 8) {
                ForEach(rest.indices, id: \.self) { index in
                    ingredientCell(rest[index].name, kind: rest[index].kind, amount: rest[index].amount, size: size)
                }
            }
        }
    }

    private func ingredientCell(_ name: String, kind: IngredientKind, amount: String?, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            switch kind {
            case .normal:
                Image(systemName: "circle.fill").font(.system(size: size * 0.35)).foregroundStyle(.secondary)
                Text(LocalizedStringKey(name))
            case .extra:
                Image(systemName: "plus.circle.fill").font(.system(size: size * 0.7)).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 0) {
                    Text(LocalizedStringKey(name)).foregroundStyle(.green).bold()
                    if let amount {
                        Text(amount).font(.system(size: size * 0.55)).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            case .without:
                Image(systemName: "minus.circle.fill").font(.system(size: size * 0.7)).foregroundStyle(.red)
                Text(LocalizedStringKey(name)).strikethrough().foregroundStyle(.red)
            }
        }
        .font(.system(size: size))
        .lineLimit(2)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Untere Hälfte: Reihenfolge der Zubereitung

    private var controls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    finishCurrent()
                } label: {
                    Label("Pizza done", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(current == nil || current?.done == true)

                Button { withAnimation { isSorting.toggle() } } label: { isSorting ? Text("Done sorting") : Text("Reorder") }
                    .buttonStyle(.bordered)

                Menu {
                    if !isFixed {
                        Button("Fetch guest orders", systemImage: "icloud.and.arrow.down") { Task { await fetch() } }
                            .disabled(isBusy || eventID.isEmpty)
                    }
                    Button("Sort by guest", systemImage: "person.2") { sortByGuest() }
                    Button("Sort by pizza", systemImage: "list.number") { sortByPizza() }
                    Button("Reset done", systemImage: "arrow.counterclockwise") {
                        for index in queue.indices { queue[index].done = false }
                        selectedID = nil
                    }
                    Divider()
                    Toggle("Swap top and bottom", isOn: $swapHalves)
                    Toggle("Show next pizza with ingredients", isOn: $showNextPizza)
                    // Als Untermenüs, damit die Auswahl ihre Überschrift behält
                    Picker(selection: $foldColumns) {
                        Text("2 columns").tag(2)
                        Text("3 columns").tag(3)
                    } label: {
                        Label("Ingredient columns", systemImage: "square.grid.2x2")
                    }
                    .pickerStyle(.menu)
                    Picker(selection: $hingeGap) {
                        Text("No gap").tag(0.0)
                        Text("Small gap").tag(24.0)
                        Text("Large gap").tag(48.0)
                    } label: {
                        Label("Gap for the fold", systemImage: "arrow.up.and.down")
                    }
                    .pickerStyle(.menu)
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title2)
                }

                Button("Close") { dismiss() }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            List {
                Section {
                    ForEach(Array(queue.enumerated()), id: \.element.id) { entry in
                        prepRow(entry.element, position: entry.offset + 1)
                    }
                    .onMove { queue.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Order of preparation")
                } footer: {
                    if !status.isEmpty { Text(status) }
                    else { Text("Tap a pizza to show it on top. Tap “Reorder” and drag to change the order.") }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(isSorting ? .active : .inactive))
        }
    }

    private func prepRow(_ item: PrepItem, position: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleDone(item)
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(item.done ? .green : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(position). \(item.guest.isEmpty ? pizzaTitle(item) : item.guest)").font(.headline)
                if !item.guest.isEmpty || !item.extra.isEmpty || !item.without.isEmpty {
                    Text(rowDetail(item)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { selectedID = item.id }

            if item.id == current?.id {
                Image(systemName: "eye.fill").foregroundStyle(.tint)
            }
        }
        .opacity(item.done ? 0.5 : 1)
    }

    private func rowDetail(_ item: PrepItem) -> String {
        var parts: [String] = []
        if !item.guest.isEmpty { parts.append(pizzaTitle(item)) }
        if !item.extra.isEmpty { parts.append("+ " + item.extra.joined(separator: ", ")) }
        if !item.without.isEmpty { parts.append(String(localized: "without") + " " + item.without.joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Aktionen

    private func toggleDone(_ item: PrepItem) {
        guard let index = queue.firstIndex(where: { $0.id == item.id }) else { return }
        queue[index].done.toggle()
        if queue[index].done && selectedID == item.id { selectedID = nil }
    }

    /// Aktuelle Pizza abhaken, oben erscheint die nächste
    private func finishCurrent() {
        guard let item = current, let index = queue.firstIndex(where: { $0.id == item.id }) else { return }
        queue[index].done = true
        selectedID = nil
    }

    private func sortByGuest() {
        queue.sort { $0.guest.localizedCaseInsensitiveCompare($1.guest) == .orderedAscending }
    }

    private func sortByPizza() {
        let order = Dictionary(pizzas.enumerated().map { ($0.element.name, $0.offset) }, uniquingKeysWith: { a, _ in a })
        queue.sort { (order[$0.pizza] ?? .max, $0.guest) < (order[$1.pizza] ?? .max, $1.guest) }
    }

    private func rebuild(orders: [GuestOrder]) {
        let fresh = PrepQueueStore.items(orders: orders, pizzas: pizzas)
        let saved = queue.isEmpty ? PrepQueueStore.queue(event: eventID) : queue
        queue = PrepQueueStore.merge(fresh, into: saved)
    }

    private func fetch() async {
        isBusy = true; defer { isBusy = false }
        let service = GuestOrderService(project: project.trimmingCharacters(in: .whitespaces),
                                        apiKey: apiKey.trimmingCharacters(in: .whitespaces))
        do {
            let orders = try await service.fetchOrders(id: eventID)
            PrepQueueStore.saveOrders(orders, event: eventID)
            if !orders.isEmpty {
                MenuPizza.apply(orders: orders, to: pizzas.filter { $0.isOnMenu && !$0.isGuestCustom }, context: modelContext)
                try? modelContext.save()
            }
            rebuild(orders: orders)
            status = String(localized: "\(orders.count) orders received.")
        } catch {
            status = error.localizedDescription
        }
    }
}

#Preview {
    OrdersFoldView()
}
