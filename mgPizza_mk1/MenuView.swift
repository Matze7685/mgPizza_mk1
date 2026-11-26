//
//  MenuView.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

/// Tab „Anlass“: alle Anlässe auf einen Blick, neuen Anlass anlegen. Pizzen und Mengen liegen im Untermenü.
struct EventsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("menuEventID") private var eventID = ""
    @AppStorage("menuTitle") private var menuTitle = ""
    @AppStorage("menuDate") private var menuDate: Double = Date().timeIntervalSince1970
    @AppStorage("guestNames") private var guestNames = ""
    @AppStorage("guestIntro") private var intro = ""
    @AppStorage("guestOrdersClosed") private var ordersClosed = false
    @AppStorage("menuHiddenPizzas") private var hiddenText = ""
    @AppStorage("menuEventDone") private var isDone = false
    @AppStorage("menuFixedMode") private var isFixed = false
    @State private var evenings: [GuestEvening] = []
    @State private var showingNew = false
    @State private var created: GuestEvening?
    @State private var openEvening: GuestEvening?
    @State private var deleting: GuestEvening?

    private var upcoming: [GuestEvening] { evenings.filter { !$0.isPast }.sorted { $0.date < $1.date } }
    private var past: [GuestEvening] { evenings.filter(\.isPast).sorted { $0.date > $1.date } }

    var body: some View {
        List {
            Section {
                Button { showingNew = true } label: {
                    Label("New event", systemImage: "plus.circle.fill").font(.headline)
                }
            } footer: {
                if evenings.isEmpty {
                    Text("Create your first event: name and date. Then add the guests and publish the menu.")
                }
            }
            if !upcoming.isEmpty {
                Section("Upcoming") { ForEach(upcoming) { row($0) } }
            }
            if !past.isEmpty {
                Section("Past") { ForEach(past) { row($0) } }
            }
            Section {
                NavigationLink { MenuSettingsView() } label: {
                    Label("Pizzas & amounts", systemImage: "slider.horizontal.3")
                }
            } footer: {
                Text("Which pizzas can be chosen, toppings per pizza, extra amounts and settings of the guest page.")
            }
        }
        .navigationDestination(item: $openEvening) { evening in
            EventDetailView(evening: evening)
        }
        .sheet(isPresented: $showingNew, onDismiss: {
            // Nach dem Anlegen direkt in den neuen Anlass
            if let created { openEvening = created; self.created = nil }
        }) {
            NewEventSheet { title, date, text, fixed in
                var evening = GuestEvening(id: GuestEvenings.newID(), title: title, date: date, intro: text)
                if fixed { evening.fixedCounts = [:] }
                GuestEvenings.upsert(evening)
                created = evening
                reload()
            }
        }
        .confirmationDialog("Delete “\(deleting?.title ?? "")”?", isPresented: Binding { deleting != nil } set: { if !$0 { deleting = nil } },
                            titleVisibility: .visible) {
            Button("Delete event", role: .destructive) {
                if let evening = deleting { Task { await delete(evening) } }
                deleting = nil
            }
        } message: {
            Text("The guest link stops working and the event disappears from the app.")
        }
        .refreshable { await refreshCounts() }
        .onAppear {
            migrate()
            reload()
            MenuPizza.seedIfNeeded(into: modelContext)
            MenuPizza.seedMoreIfNeeded(into: modelContext)
            MenuPizza.addGratedCheeseIfNeeded(into: modelContext)
        }
        .onChange(of: openEvening) { _, open in if open == nil { reload() } }
    }

    private func row(_ evening: GuestEvening) -> some View {
        Button { openEvening = evening } label: {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(evening.date.formatted(.dateTime.day())).font(.title2.bold())
                    Text(evening.date.formatted(.dateTime.month(.abbreviated))).font(.caption.smallCaps())
                }
                .frame(width: 46, height: 46)
                .background(.tint.opacity(evening.isPast ? 0.08 : 0.18), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(evening.title).font(.headline).foregroundStyle(.primary)
                    Text(evening.date.formatted(.dateTime.weekday(.wide).hour().minute()))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(details(evening)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash") { deleting = evening }
                .tint(.red)
        }
        .swipeActions(edge: .leading) {
            if evening.publishedAt != nil, let link = GuestEvenings.link(id: evening.id) {
                Button("Copy link", systemImage: "doc.on.doc") { UIPasteboard.general.string = link.absoluteString }
                    .tint(.blue)
            }
        }
    }

    private func details(_ evening: GuestEvening) -> String {
        if let counts = evening.fixedCounts {
            let total = counts.values.reduce(0, +)
            return String(localized: "\(total) pizzas · fixed quantities")
        }
        var parts = [String(localized: "\(evening.guests.count) guests")]
        if let count = evening.orderCount { parts.append(String(localized: "\(count) orders")) }
        if evening.publishedAt == nil {
            parts.append(String(localized: "not published"))
        } else if evening.closed {
            parts.append(String(localized: "orders closed"))
        }
        return parts.joined(separator: " · ")
    }

    private func reload() { evenings = GuestEvenings.all }

    /// Früher gab es nur einen Abend ohne Übersicht: diesen einmalig übernehmen
    private func migrate() {
        guard !GuestEvenings.exists else { return }
        let guests = guestNames.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !eventID.isEmpty, !guests.isEmpty else { GuestEvenings.save([]); return }
        var old = GuestEvening(id: eventID, title: menuTitle.isEmpty ? String(localized: "Pizza night") : menuTitle,
                               date: Date(timeIntervalSince1970: menuDate), intro: intro, guests: guests, closed: ordersClosed)
        old.publishedAt = .now
        GuestEvenings.save([old])
    }

    private func delete(_ evening: GuestEvening) async {
        if evening.publishedAt != nil { try? await GuestOrderService.current.deleteEvent(id: evening.id) }
        GuestEvenings.remove(id: evening.id)
        if evening.id == eventID {
            // Der gelöschte Anlass war der aktuelle: leer weitermachen
            eventID = ""
            menuTitle = ""
            guestNames = ""
            intro = ""
            ordersClosed = false
            hiddenText = ""
            isDone = false
            isFixed = false
            UserDefaults.standard.removeObject(forKey: "menuFixedExtras")
        }
        reload()
    }

    /// Bestellanzahl aller veröffentlichten Anlässe neu abholen
    private func refreshCounts() async {
        let service = GuestOrderService.current
        for evening in evenings where evening.publishedAt != nil {
            guard let orders = try? await service.fetchOrders(id: evening.id) else { continue }
            var updated = evening
            updated.orderCount = orders.count
            GuestEvenings.upsert(updated)
        }
        reload()
    }
}

/// Ein Anlass in vier Schritten: 1 Anlass, 2 Gäste, 3 Speisekarte veröffentlichen, 4 Bestellungen
struct EventDetailView: View {
    let evening: GuestEvening
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MenuPizza.sortIndex) private var pizzas: [MenuPizza]
    @Query private var sauces: [SauceRecipe]
    @AppStorage("menuEventID") private var eventID = ""
    @AppStorage("menuTitle") private var menuTitle = ""
    @AppStorage("menuDate") private var menuDate: Double = Date().timeIntervalSince1970
    @AppStorage("guestNames") private var guestNames = ""
    @AppStorage("guestIntro") private var intro = ""
    @AppStorage("guestOrdersClosed") private var ordersClosed = false
    @AppStorage("menuHiddenPizzas") private var hiddenText = ""
    @AppStorage("menuEventDone") private var isDone = false
    @AppStorage("menuFixedMode") private var isFixed = false
    /// Feste Mengen: Extras pro Sorte als JSON (Pizza-Name -> Extras)
    @AppStorage("menuFixedExtras") private var fixedExtrasJSON = ""
    @State private var choosingExtras: MenuPizza?
    @State private var orders: [GuestOrder] = []
    @State private var publishedAt: Date?
    @State private var status = ""
    @State private var isBusy = false
    @State private var newGuest = ""
    @State private var renaming: String?
    @State private var renameText = ""
    @State private var removing: String?
    @State private var deletingOrder: String?
    @State private var showingGuestPicker = false
    @State private var showingFoldView = false
    @State private var confirmingDelete = false
    @State private var editingPizza: MenuPizza?
    @State private var pdfURL: URL?

    private var service: GuestOrderService { .current }
    private var guests: [String] {
        guestNames.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var hidden: Set<String> { Set(hiddenText.split(separator: "\n").map(String.init)) }
    private var date: Date { Date(timeIntervalSince1970: menuDate) }
    private var dateBinding: Binding<Date> { Binding { date } set: { menuDate = $0.timeIntervalSince1970 } }
    private var title: String { menuTitle.isEmpty ? String(localized: "Pizza night") : menuTitle }
    private var isOverByDate: Bool { date < Calendar.current.startOfDay(for: .now) }
    private var isPast: Bool { isDone || isOverByDate }
    private var isPublished: Bool { publishedAt != nil }
    private var guestLink: URL? { GuestEvenings.link(id: eventID) }

    /// Alle auswählbaren Pizzen (Untermenü „Pizzen & Mengen“)
    private var available: [MenuPizza] { pizzas.filter { $0.isOnMenu && !$0.isGuestCustom } }
    /// Die Karte dieses Anlasses
    private var eventPizzas: [MenuPizza] { available.filter { !hidden.contains($0.name) } }
    /// Für Bestellungen: Karte + eigene Pizzen der Gäste; bei festen Mengen alle auswählbaren Pizzen
    private var orderPizzas: [MenuPizza] { isFixed ? available : eventPizzas + pizzas.filter(\.isGuestCustom) }
    /// Feste Mengen dieses Anlasses (Pizza-Name -> Anzahl), nur Pizzen mit Anzahl > 0
    private var fixedCounts: [String: Int] {
        Dictionary(available.filter { $0.orderCount > 0 }.map { ($0.name, $0.orderCount) }, uniquingKeysWith: +)
    }
    private var fixedExtras: [String: [String]] {
        (try? JSONDecoder().decode([String: [String]].self, from: Data(fixedExtrasJSON.utf8))) ?? [:]
    }
    private var totalOrders: Int { orderPizzas.reduce(0) { $0 + $1.orderCount } }
    private var roundCount: Int { orderPizzas.filter { !$0.isDetroit }.reduce(0) { $0 + $1.orderCount } }
    private var detroitCount: Int { orderPizzas.filter(\.isDetroit).reduce(0) { $0 + $1.orderCount } }
    private var sauce: SauceRecipe? { SauceRecipe.preferred(sauces) }

    /// Der Anlass, wie er in der Übersicht gespeichert wird
    private var current: GuestEvening {
        GuestEvening(id: eventID, title: title, date: date, intro: intro, guests: guests, closed: ordersClosed,
                     hiddenPizzas: hidden.isEmpty ? nil : Array(hidden).sorted(), done: isDone ? true : nil,
                     fixedCounts: isFixed ? fixedCounts : nil,
                     fixedExtras: isFixed && !fixedExtras.isEmpty ? fixedExtras : nil)
    }

    var body: some View {
        Form {
            if eventID == evening.id {
                eventSection
                if isFixed {
                    fixedPizzasSection
                    fixedPrepSection
                } else {
                    guestSection
                    menuSection
                    ordersSection
                }
                if totalOrders > 0 { toppingsSection }
                Section {
                    if isDone {
                        Button("Reopen event", systemImage: "arrow.uturn.backward") { isDone = false }
                    } else if !isOverByDate {
                        Button("Mark event as done", systemImage: "checkmark.seal") { markDone() }
                    }
                    Button("Delete event", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } footer: {
                    if !isDone && !isOverByDate {
                        Text("An event moves to “Past” automatically at midnight after its day, or right away when you mark it as done. Orders are then closed.")
                    }
                }
                if !status.isEmpty {
                    Section { Text(status).font(.callout) }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if eventID != evening.id { switchTo(evening) }
            publishedAt = GuestEvenings.all.first { $0.id == evening.id }?.publishedAt
            // Bei festen Mengen keine Gästebestellungen übernehmen (würden die Mengen überschreiben)
            if isPublished && !isFixed { await loadOrders(updateShopping: false) }
        }
        // Jede Änderung gleich in der Übersicht speichern
        .onChange(of: current) { _, new in if new.id == evening.id { GuestEvenings.upsert(new) } }
        // Extras folgen der Stückzahl ihrer Sorte (für Belag und Einkaufsliste)
        .onChange(of: fixedCounts) { _, _ in if isFixed { syncFixedExtras() } }
        .sheet(item: $choosingExtras) { pizza in
            ExtrasPickerSheet(pizza: pizza, selected: Set(fixedExtras[pizza.name] ?? [])) { names in
                setExtras(names, for: pizza)
            }
        }
        .task(id: shareText) { pdfURL = MenuPDF.render(title: title, date: date, pizzas: eventPizzas) }
        .alert("Rename guest", isPresented: Binding { renaming != nil } set: { if !$0 { renaming = nil } }) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") {
                if let old = renaming { Task { await rename(old, to: renameText) } }
                renaming = nil
            }
        }
        .confirmationDialog("Remove \(removing ?? "")?", isPresented: Binding { removing != nil } set: { if !$0 { removing = nil } },
                            titleVisibility: .visible) {
            Button("Remove guest and order", role: .destructive) {
                if let name = removing { Task { await remove(name) } }
                removing = nil
            }
        } message: {
            Text("If this guest has already ordered, the order is deleted too.")
        }
        .confirmationDialog("Delete the order of \(deletingOrder ?? "")?", isPresented: Binding { deletingOrder != nil } set: { if !$0 { deletingOrder = nil } },
                            titleVisibility: .visible) {
            Button("Delete order", role: .destructive) {
                if let name = deletingOrder { Task { await deleteGuestOrder(name) } }
                deletingOrder = nil
            }
        }
        .confirmationDialog("Delete “\(title)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete event", role: .destructive) { Task { await deleteEvent() } }
        } message: {
            Text("The guest link stops working and the event disappears from the app.")
        }
        .sheet(isPresented: $showingGuestPicker) {
            GuestPickerSheet(evenings: GuestEvenings.all.filter { $0.id != eventID }, existing: guests) { names in
                addGuests(names)
            }
        }
        .sheet(item: $editingPizza) { pizza in
            MenuPizzaEditor(pizza: pizza)
        }
        .fullScreenCover(isPresented: $showingFoldView) {
            OrdersFoldView()
        }
    }

    // MARK: 1 · Anlass

    private var eventSection: some View {
        Section {
            TextField("Pizza night", text: $menuTitle)
            DatePicker("Date", selection: dateBinding)
            if !isFixed {
                TextField("Welcome text for guests (optional)", text: $intro, axis: .vertical)
                    .lineLimit(1...5)
            }
            PlanModePicker(isFixed: Binding { isFixed } set: { setFixed($0) })
        } header: {
            Text("1 · Event")
        } footer: {
            if isFixed {
                Text("Fixed quantities: you decide how many of each pizza you make. No guest list, no guest page.")
            } else if isPublished {
                Text("Changes reach the guests after publishing the menu again.")
            }
        }
    }

    // MARK: Feste Mengen

    private var fixedPizzasSection: some View {
        Section {
            ForEach(available) { pizza in
                VStack(alignment: .leading, spacing: 6) {
                    MenuPizzaRow(pizza: pizza, number: nil, showsOrders: true) { editingPizza = pizza }
                    if pizza.orderCount > 0 {
                        let extras = fixedExtras[pizza.name] ?? []
                        Button { choosingExtras = pizza } label: {
                            if extras.isEmpty {
                                Label("Add extras", systemImage: "plus.circle").font(.subheadline)
                            } else {
                                Label("Extra: \(extras.joined(separator: ", "))", systemImage: "plus.circle.fill")
                                    .font(.subheadline).foregroundStyle(.green)
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .opacity(pizza.orderCount > 0 ? 1 : 0.6)
            }
            if available.isEmpty {
                Text("No pizzas available – choose them in “Pizzas & amounts”.").foregroundStyle(.secondary)
            } else {
                LabeledContent("Total", value: String(localized: "\(totalOrders) pizzas"))
                    .font(.headline)
            }
        } header: {
            Text("2 · Pizzas")
        } footer: {
            Text("Set how many of each pizza you make, e.g. 5× Salami and 5× Tuna. Extras apply to every pizza of that kind. Preparation and shopping list use these numbers.")
        }
    }

    private var fixedPrepSection: some View {
        Section {
            Button("Split view: preparation order", systemImage: "rectangle.split.1x2") { showingFoldView = true }
                .disabled(totalOrders == 0)
        } header: {
            Text("3 · Preparation")
        }
    }

    // MARK: 2 · Gäste

    private var guestSection: some View {
        Section {
            ForEach(guests, id: \.self) { name in
                Button {
                    renameText = name
                    renaming = name
                } label: {
                    HStack {
                        Text(name).foregroundStyle(.primary)
                        Spacer()
                        if orders.contains(where: { $0.guest == name }) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
                .swipeActions {
                    Button("Remove", systemImage: "trash", role: .destructive) { removing = name }
                }
            }
            HStack {
                TextField("Add guest", text: $newGuest)
                    .onSubmit(addTypedGuests)
                Button("Add", systemImage: "plus.circle.fill", action: addTypedGuests)
                    .labelStyle(.iconOnly)
                    .disabled(newGuest.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if GuestEvenings.all.contains(where: { $0.id != eventID && !$0.guests.isEmpty }) {
                Button("Guests from earlier events", systemImage: "person.2.badge.plus") { showingGuestPicker = true }
            }
        } header: {
            Text("2 · Guests (\(guests.count))")
        } footer: {
            Text("Tap a name to rename, swipe to remove. Several names at once: separate with commas.")
        }
    }

    // MARK: 3 · Speisekarte

    private var menuSection: some View {
        Section {
            DisclosureGroup {
                ForEach(available) { pizza in
                    let isOn = !hidden.contains(pizza.name)
                    Button {
                        var set = hidden
                        if isOn { set.insert(pizza.name) } else { set.remove(pizza.name) }
                        hiddenText = set.sorted().joined(separator: "\n")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundStyle(isOn ? .green : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pizza.name).foregroundStyle(.primary)
                                if !pizza.toppingsText.isEmpty {
                                    Text(pizza.toppingsText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                }
                if available.isEmpty {
                    Text("No pizzas available – choose them in “Pizzas & amounts”.").foregroundStyle(.secondary)
                }
            } label: {
                LabeledContent("Pizzas on the menu", value: "\(eventPizzas.count)/\(available.count)")
            }
            Button(isPublished ? "Publish menu again" : "Publish menu", systemImage: "icloud.and.arrow.up") {
                Task { await publish() }
            }
            .disabled(isBusy || eventPizzas.isEmpty)
            if isPublished, let link = guestLink {
                // Als reiner Text teilen: Mit URL + message schicken manche Apps (WhatsApp, Nachrichten) nur die Nachricht
                ShareLink(item: "🍕 \(title)\n\(link.absoluteString)") {
                    Label("Send guest link", systemImage: "link")
                }
                Button("Copy guest link", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = link.absoluteString
                    status = String(localized: "Link copied.")
                }
                Link(destination: link) {
                    Label("Open guest page", systemImage: "safari")
                }
            }
            Menu {
                ShareLink(item: shareText, subject: Text(title)) {
                    Label("Send menu as text (WhatsApp, Messages …)", systemImage: "text.bubble")
                }
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Send menu as PDF", systemImage: "doc.richtext")
                    }
                }
            } label: {
                Label("Send menu without guest page", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("3 · Menu")
        } footer: {
            Text("Untick pizzas you don't want to offer at this event. After publishing, the guest link is copied: paste it into your message.")
        }
    }

    // MARK: 4 · Bestellungen

    private var ordersSection: some View {
        Section {
            if isPast {
                Label("This event is over", systemImage: "flag.checkered").foregroundStyle(.secondary)
            } else {
                Toggle("Orders closed", systemImage: "lock", isOn: Binding {
                    ordersClosed
                } set: { closed in
                    ordersClosed = closed
                    if isPublished { Task { await publish(quiet: true) } }
                })
            }
            if isPublished {
                Button("Fetch orders", systemImage: "icloud.and.arrow.down") { Task { await loadOrders(updateShopping: true) } }
                    .disabled(isBusy)
            }
            ForEach(orders) { order in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(order.guest).font(.headline)
                        if order.claimed == true { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary) }
                    }
                    Text(order.lines.map { "\($0.count)× \($0.name)" + ($0.custom.map { " (\($0.map(\.name).joined(separator: ", ")))" } ?? "") + (($0.extra ?? []).isEmpty ? "" : " + \($0.extra!.joined(separator: ", "))") + ($0.without.isEmpty ? "" : " (\(String(localized: "without")) \($0.without.joined(separator: ", ")))") }
                        .joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button("Delete order", systemImage: "trash", role: .destructive) { deletingOrder = order.guest }
                    if order.claimed == true {
                        Button("Release for new device", systemImage: "lock.open") { Task { await release(order.guest) } }
                            .tint(.orange)
                    }
                }
            }
            let missing = guests.filter { name in !orders.contains { $0.guest == name } }
            if !orders.isEmpty && !missing.isEmpty {
                Text("Still missing: \(missing.joined(separator: ", "))").font(.caption).foregroundStyle(.orange)
            }
            DisclosureGroup {
                ForEach(orderPizzas) { pizza in
                    MenuPizzaRow(pizza: pizza, number: number(of: pizza), showsOrders: true) { editingPizza = pizza }
                }
            } label: {
                LabeledContent("Pizzas ordered", value: "\(totalOrders)")
            }
            Button("Split view: guests on top, preparation below", systemImage: "rectangle.split.1x2") { showingFoldView = true }
        } header: {
            Text("4 · Orders")
        } footer: {
            Text("Orders from the guest page are counted automatically. Without guest page: enter the counts by hand under “Pizzas ordered”. Swipe an order to release it for a new phone or to delete it.")
        }
    }

    private var toppingsSection: some View {
        Section {
            ForEach(MenuPizza.aggregatedToppings(of: orderPizzas), id: \.key) { item in
                LabeledContent(item.name, value: MenuPizza.formatted(item.amount, unit: item.unit))
            }
            Button("Put on shopping list", systemImage: "cart.badge.plus") {
                updateShoppingList()
                AppRouter.shared.selectedTab = .shopping
            }
            Button("Reset orders", systemImage: "arrow.counterclockwise", role: .destructive) { resetOrderCounts() }
        } header: {
            Text("Needed toppings")
        } footer: {
            if let sauce {
                Text("Dough: \(roundCount) dough balls, \(detroitCount) Detroit pans. On the shopping list the tomato sauce is split into its ingredients (recipe “\(sauce.displayName)”).")
            } else {
                Text("Dough: \(roundCount) dough balls, \(detroitCount) Detroit pans – create the dough recipe with the + button.")
            }
        }
    }

    private func number(of pizza: MenuPizza) -> Int? {
        eventPizzas.firstIndex { $0.persistentModelID == pizza.persistentModelID }.map { $0 + 1 }
    }

    /// Text für WhatsApp & Co.
    private var shareText: String {
        var lines = ["🍕 \(title) – \(date.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))", ""]
        for (index, pizza) in eventPizzas.enumerated() {
            lines.append("\(index + 1). \(pizza.name)" + (pizza.info.isEmpty ? "" : " (\(pizza.info))"))
            if !pizza.toppingsText.isEmpty { lines.append("    \(pizza.toppingsText)") }
        }
        lines.append("")
        lines.append(String(localized: "Please reply with number × count, e.g. “1×2, 3×1”. Thanks!"))
        return lines.joined(separator: "\n")
    }

    // MARK: Aktionen

    /// Diesen Anlass zum aktuellen machen (Titel, Datum, Gäste, Text, Karte); Bestellzahlen des vorherigen werden zurückgesetzt
    private func switchTo(_ evening: GuestEvening) {
        eventID = evening.id
        menuTitle = evening.title
        menuDate = evening.date.timeIntervalSince1970
        intro = evening.intro
        ordersClosed = evening.closed
        guestNames = evening.guests.joined(separator: "\n")
        hiddenText = (evening.hiddenPizzas ?? []).joined(separator: "\n")
        isDone = evening.done == true
        isFixed = evening.isFixed
        orders = []
        resetOrderCounts()
        // Feste Mengen wiederherstellen
        if let counts = evening.fixedCounts {
            for pizza in pizzas where !pizza.isGuestCustom { pizza.orderCount = counts[pizza.name] ?? 0 }
        }
        fixedExtrasJSON = Self.encode(evening.fixedExtras ?? [:])
        if evening.isFixed { syncFixedExtras() }
    }

    private static func encode(_ extras: [String: [String]]) -> String {
        guard !extras.isEmpty, let data = try? JSONEncoder().encode(extras) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Extras einer Sorte setzen (feste Mengen)
    private func setExtras(_ names: [String], for pizza: MenuPizza) {
        var all = fixedExtras
        all[pizza.name] = names.isEmpty ? nil : names
        fixedExtrasJSON = Self.encode(all)
        syncFixedExtras()
    }

    /// Feste Mengen: jedes Extra zählt so oft, wie Pizzen dieser Sorte gemacht werden
    private func syncFixedExtras() {
        let extras = fixedExtras
        for pizza in available {
            let names = pizza.orderCount > 0 ? extras[pizza.name] ?? [] : []
            let wanted = Dictionary(names.map { ($0, pizza.orderCount) }, uniquingKeysWith: { a, _ in a })
            if pizza.guestExtras != wanted { pizza.guestExtras = wanted }
        }
    }

    /// Zwischen „Gäste bestellen“ und „Feste Mengen“ wechseln. Vorhandene Zahlen bleiben als Startwert stehen.
    private func setFixed(_ fixed: Bool) {
        guard fixed != isFixed else { return }
        isFixed = fixed
        if !fixed {
            fixedExtrasJSON = ""
            for pizza in available { pizza.guestExtras = [:] }
        }
        if fixed {
            for pizza in available { pizza.guestExtras = [:] }
            // Eigene Pizzen der Gäste gehören nicht zu festen Mengen
            for pizza in pizzas where pizza.isGuestCustom { modelContext.delete(pizza) }
            orders = []
            PrepQueueStore.saveOrders([], event: eventID)
            // Gästeseite schließen, damit dort niemand mehr bestellt
            if isPublished && !ordersClosed {
                ordersClosed = true
                Task { await publish(quiet: true) }
            }
        }
    }

    /// Anlass erledigt: wandert zu „Vergangene“, Bestellung wird geschlossen
    private func markDone() {
        isDone = true
        if !ordersClosed {
            ordersClosed = true
            if isPublished { Task { await publish(quiet: true) } }
        }
    }

    private func resetOrderCounts() {
        for pizza in pizzas {
            if pizza.isGuestCustom {
                modelContext.delete(pizza)
            } else {
                pizza.orderCount = 0
                pizza.removedToppings = [:]
                pizza.guestExtras = [:]
            }
        }
    }

    private func addTypedGuests() {
        addGuests(newGuest.split(whereSeparator: { $0 == "," || $0 == "\n" }).map { $0.trimmingCharacters(in: .whitespaces) })
        newGuest = ""
    }

    /// Namen hinzufügen, ohne Doppelte
    private func addGuests(_ names: [String]) {
        var list = guests
        for name in names where !name.isEmpty && !list.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            list.append(name)
        }
        guestNames = list.joined(separator: "\n")
        if isPublished { Task { await publish(quiet: true) } }
    }

    private func rename(_ old: String, to newName: String) async {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != old else { return }
        if guests.contains(where: { $0 != old && $0.caseInsensitiveCompare(name) == .orderedSame }) {
            status = String(localized: "“\(name)” is already on the list.")
            return
        }
        guestNames = guests.map { $0 == old ? name : $0 }.joined(separator: "\n")
        if let i = orders.firstIndex(where: { $0.guest == old }) { orders[i].guest = name }
        guard isPublished else { return }
        do {
            try await service.renameOrder(id: eventID, from: old, to: name)
            await publish(quiet: true)
        } catch { status = error.localizedDescription }
    }

    private func remove(_ name: String) async {
        guestNames = guests.filter { $0 != name }.joined(separator: "\n")
        orders.removeAll { $0.guest == name }
        guard isPublished else { return }
        do {
            try await service.deleteOrder(id: eventID, guest: name)
            await publish(quiet: true)
        } catch { status = error.localizedDescription }
    }

    private func release(_ name: String) async {
        do {
            try await service.releaseOrder(id: eventID, guest: name)
            orders = try await service.fetchOrders(id: eventID)
            PrepQueueStore.saveOrders(orders, event: eventID)   // für die geteilte Ansicht (Gästenamen)
            status = String(localized: "Order of \(name) released. The next device that saves it takes it over.")
        } catch { status = error.localizedDescription }
    }

    private func deleteGuestOrder(_ name: String) async {
        do {
            try await service.deleteOrder(id: eventID, guest: name)
            orders.removeAll { $0.guest == name }
            MenuPizza.apply(orders: orders, to: available, context: modelContext)
        } catch { status = error.localizedDescription }
    }

    /// Karte + Gäste hochladen. Beim ersten Mal liegt der Link danach in der Zwischenablage.
    private func publish(quiet: Bool = false) async {
        isBusy = true; defer { isBusy = false }
        let text = intro.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = GuestEvent(title: title, date: date, guests: guests, pizzas: eventPizzas.map { pizza in
            .init(name: pizza.name, info: pizza.info,
                  toppings: pizza.toppings.map { .init(name: $0.name, amount: $0.amount, unit: $0.unit) })
        }, intro: text.isEmpty ? nil : text, closed: ordersClosed ? true : nil, extras: MenuPizza.alwaysOfferedExtras,
           extraAmounts: ExtraDefaults.all.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
               .map { GuestEvent.Topping(name: $0.name.trimmingCharacters(in: .whitespaces), amount: $0.amount, unit: $0.unit) })
        let first = !isPublished
        do {
            try await service.publish(event, id: eventID)
            var saved = current
            saved.publishedAt = .now
            GuestEvenings.upsert(saved)
            publishedAt = saved.publishedAt
            if quiet { return }
            if first, let link = guestLink {
                UIPasteboard.general.string = link.absoluteString
                status = String(localized: "Published. The guest link is copied: paste it into your message.")
            } else {
                status = String(localized: "Published. Send the guest link.")
            }
        } catch { status = error.localizedDescription }
    }

    /// Bestellungen abholen und in die Karte übernehmen; auf Wunsch auch die Einkaufsliste aktualisieren
    private func loadOrders(updateShopping: Bool) async {
        isBusy = true; defer { isBusy = false }
        do {
            orders = try await service.fetchOrders(id: eventID)
            PrepQueueStore.saveOrders(orders, event: eventID)   // für die geteilte Ansicht (Gästenamen)
            var saved = current
            saved.orderCount = orders.count
            GuestEvenings.upsert(saved)
            // Ohne Online-Bestellungen bleiben von Hand eingetragene Zahlen stehen
            if !orders.isEmpty {
                MenuPizza.apply(orders: orders, to: available, context: modelContext)
                try? modelContext.save()
            }
            if updateShopping {
                if totalOrders > 0 { updateShoppingList() }
                status = orders.isEmpty ? String(localized: "No orders yet.")
                                        : String(localized: "\(orders.count) orders received, shopping list updated.")
            }
        } catch {
            if updateShopping { status = error.localizedDescription }
        }
    }

    /// Zutaten dieses Anlasses auf die Einkaufsliste (ersetzt frühere, noch nicht abgehakte Einträge)
    private func updateShoppingList() {
        let all = (try? modelContext.fetch(FetchDescriptor<MenuPizza>())) ?? []
        let ordered = isFixed ? all.filter { $0.isOnMenu && !$0.isGuestCustom }
                              : all.filter { $0.isGuestCustom || ($0.isOnMenu && !hidden.contains($0.name)) }
        ShoppingItem.replace(MenuPizza.shoppingItems(of: ordered, sauce: sauce), source: title, in: modelContext)
    }

    private func deleteEvent() async {
        if isPublished {
            do { try await service.deleteEvent(id: eventID) } catch { status = error.localizedDescription; return }
        }
        GuestEvenings.remove(id: eventID)
        eventID = ""
        menuTitle = ""
        guestNames = ""
        intro = ""
        ordersClosed = false
        hiddenText = ""
        isDone = false
        isFixed = false
        fixedExtrasJSON = ""
        resetOrderCounts()
        dismiss()
    }
}

/// Gäste von früheren Anlässen übernehmen: alle eines Anlasses oder einzelne Namen
struct GuestPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var evenings: [GuestEvening]
    var existing: [String]
    var onAdd: ([String]) -> Void
    @State private var selected: Set<String> = []

    private func isNew(_ name: String) -> Bool {
        !existing.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Alle bekannten Namen, die noch nicht auf der Liste stehen
    private var names: [String] {
        var seen: [String] = []
        for name in evenings.sorted(by: { $0.date > $1.date }).flatMap(\.guests)
        where isNew(name) && !seen.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            seen.append(name)
        }
        return seen.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("All guests of an event") {
                    ForEach(evenings.filter { !$0.guests.isEmpty }.sorted { $0.date > $1.date }) { evening in
                        Button {
                            selected.formUnion(evening.guests.filter(isNew))
                        } label: {
                            LabeledContent(evening.title, value: "\(evening.guests.count)")
                        }
                        .foregroundStyle(.primary)
                    }
                }
                Section("Single guests") {
                    ForEach(names, id: \.self) { name in
                        Button {
                            if selected.contains(name) { selected.remove(name) } else { selected.insert(name) }
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(name) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(name) ? .green : .gray)
                                Text(name).foregroundStyle(.primary)
                            }
                        }
                    }
                    if names.isEmpty {
                        Text("All earlier guests are already on the list.").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Earlier guests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selected.count))") {
                        onAdd(names.filter(selected.contains))
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
}

/// Neuen Anlass anlegen: nur Name und Datum (Text optional). Danach geht es direkt zu Gästen und Speisekarte.
struct NewEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String, Date, String, Bool) -> Void

    @State private var title = ""
    @State private var fixed = false
    @State private var date = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: .now) ?? .now
    @State private var intro = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name of the event, e.g. Anna's 40th", text: $title)
                    DatePicker("Date", selection: $date)
                    if !fixed {
                        TextField("Welcome text for guests (optional)", text: $intro, axis: .vertical).lineLimit(1...4)
                    }
                }
                Section {
                    PlanModePicker(isFixed: $fixed)
                } footer: {
                    if fixed {
                        Text("Next you set how many of each pizza you make, e.g. 5× Salami and 5× Tuna. No guest list needed.")
                    } else {
                        Text("Next you add the guests and publish the menu.")
                    }
                }
            }
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(title.trimmingCharacters(in: .whitespaces), date,
                                 fixed ? "" : intro.trimmingCharacters(in: .whitespacesAndNewlines), fixed)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Feste Mengen: Zusatzzutaten für eine Sorte ankreuzen (Liste „Zusatzmengen pro Pizza“, Mengen kommen von dort)
struct ExtrasPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pizza: MenuPizza
    @State var selected: Set<String>
    var onSave: ([String]) -> Void

    /// Gespeicherte Zusatzzutaten ohne das, was schon auf der Pizza ist
    private var options: [String] {
        var seen = Set<String>()
        let own = pizza.toppings.map { $0.name.lowercased() }
        return (ExtraDefaults.all.map(\.name) + MenuPizza.alwaysOfferedExtras + selected.sorted())
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { name in
                let key = name.lowercased()
                guard !key.isEmpty, !seen.contains(key) else { return false }
                seen.insert(key)
                return !own.contains { $0 == key || $0.hasPrefix(key + " ") || $0.hasPrefix(key + "(") }
            }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            // Zwei Spalten, alphabetisch (wie auf der Gästeseite)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                          alignment: .leading, spacing: 14) {
                    ForEach(options, id: \.self) { name in
                        Button {
                            if selected.contains(name) { selected.remove(name) } else { selected.insert(name) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selected.contains(name) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundStyle(selected.contains(name) ? .green : .gray)
                                Text(name).foregroundStyle(.primary).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Extras for \(pizza.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(options.filter { selected.contains($0) })
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Wie werden die Pizzen eines Anlasses geplant: Gäste bestellen selbst oder feste Mengen pro Sorte
struct PlanModePicker: View {
    @Binding var isFixed: Bool

    var body: some View {
        Picker("Pizzas", selection: $isFixed) {
            Text("Guests order").tag(false)
            Text("Fixed quantities").tag(true)
        }
        .pickerStyle(.segmented)
    }
}

/// Untermenü „Pizzen & Mengen“: auswählbare Pizzen, Belag, Zusatzmengen und Einstellungen der Gästeseite (ändert sich selten)
struct MenuSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuPizza.sortIndex) private var pizzas: [MenuPizza]
    @AppStorage("fbProject") private var project = GuestFirebaseDefaults.project
    @AppStorage("fbKey") private var apiKey = GuestFirebaseDefaults.apiKey
    @AppStorage("guestPageURL") private var pageURL = GuestFirebaseDefaults.pageURL
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

extension MenuPizza {
    /// Belag aller Bestellungen zusammengerechnet (gleicher Name + Einheit)
    /// - Parameter sauce: Mit Saucenrezept wird die Tomatensauce in ihre Zutaten aufgeteilt (für die Einkaufsliste)
    static func aggregatedToppings(of onMenu: [MenuPizza], sauce: SauceRecipe? = nil) -> [(key: String, name: String, amount: Double, unit: String)] {
        var totals: [String: (name: String, amount: Double, unit: String)] = [:]
        var order: [String] = []
        // Gleiche Zutat zusammenrechnen, auch wenn sie unterschiedlich heißt („Cooked ham“ ↔ „Schinken“,
        // „Mozzarella (fior di latte)“ ↔ „Mozzarella“) oder in anderer Einheit steht (g ↔ Stück).
        func addPlain(_ name: String, _ amount: Double, _ unit: String) {
            var key = "\(name.lowercased())|\(unit)"
            var amount = amount
            if totals[key] == nil, let match = existingKey(for: name, unit: unit, in: totals, order: order) {
                key = match.key
                if match.unit != unit, let converted = convert(amount, from: unit, to: match.unit, name: name) { amount = converted }
            }
            if totals[key] == nil { order.append(key) }
            totals[key, default: (name, 0, unit)].amount += amount
        }
        func add(_ name: String, _ amount: Double, _ unit: String) {
            if let sauce, isTomatoSauce(name), unit == "g" || unit == "ml" {
                for part in sauce.parts(forSauce: amount) where part.amount > 0 { addPlain(part.name, part.amount, part.unit) }
            } else {
                addPlain(name, amount, unit)
            }
        }
        for pizza in onMenu where pizza.orderCount > 0 {
            for topping in pizza.toppings {
                let count = max(0, pizza.orderCount - (pizza.removedToppings[topping.name] ?? 0))
                if count > 0 { add(topping.name, topping.amount * Double(count), topping.unit) }
            }
        }
        // Zusatzzutaten der Gäste mit Standardmenge pro Pizza (Einstellung „Extra amounts per pizza“)
        for pizza in onMenu where pizza.orderCount > 0 {
            for (name, count) in pizza.guestExtras.sorted(by: { $0.key < $1.key }) where count > 0 {
                let standard = ExtraDefaults.amount(for: name)
                add(name, standard.amount * Double(count), standard.unit)
            }
        }
        return order.compactMap { key -> (key: String, name: String, amount: Double, unit: String)? in
            guard let item = totals[key] else { return nil }
            return (key, item.name, item.amount, item.unit)
        }
    }

    private static func normalized(_ name: String) -> String {
        // Namen im Belag sind oft englische Schlüssel („Cooked ham“), die App zeigt sie übersetzt („Schinken“)
        Bundle.main.localizedString(forKey: name, value: nil, table: nil)
            .lowercased().replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// „Tomatensauce“, „Tomato sauce“, „Pizzasauce“ …
    static func isTomatoSauce(_ name: String) -> Bool {
        let text = normalized(name).replacingOccurrences(of: " ", with: "")
        return ["tomatensauce", "tomatosauce", "pizzasauce", "tomatensoße", "tomatensosse"].contains { text.contains($0) }
    }

    /// Menge für die Einkaufsliste: Gramm/ml ganz, Stück aufgerundet
    static func shoppingAmount(_ amount: Double, unit: String) -> String {
        switch unit {
        case "g", "ml": return formatted(amount >= 10 ? amount.rounded() : (amount * 10).rounded() / 10, unit: unit)
        case "pcs": return formatted(amount.rounded(.up), unit: unit)
        default: return formatted((amount * 4).rounded(.up) / 4, unit: unit)
        }
    }

    /// Alle Zutaten der bestellten Pizzen für die Einkaufsliste (Tomatensauce nach Rezept aufgeteilt)
    static func shoppingItems(of pizzas: [MenuPizza], sauce: SauceRecipe?) -> [(String, String)] {
        aggregatedToppings(of: pizzas, sauce: sauce).map { ($0.name, shoppingAmount($0.amount, unit: $0.unit)) }
    }

    private static func words(_ name: String) -> [String] {
        name.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "/" }).map(String.init)
    }

    /// Schon vorhandener Eintrag für dieselbe Zutat (Namen enthalten sich gegenseitig); gleiche Einheit hat Vorrang
    private static func existingKey(for name: String, unit: String, in totals: [String: (name: String, amount: Double, unit: String)],
                                    order: [String]) -> (key: String, unit: String)? {
        let wanted = normalized(name)
        guard !wanted.isEmpty else { return nil }
        let matches = order.compactMap { key -> (key: String, unit: String)? in
            guard let item = totals[key] else { return nil }
            let have = normalized(item.name)
            // ganze Wörter vergleichen: „Oliven“ passt zu „Schwarze Oliven“, „Tomaten“ aber nicht zu „Tomatensauce“
            let haveWords = Set(words(have)), wantedWords = Set(words(wanted))
            guard !haveWords.isEmpty, haveWords.isSubset(of: wantedWords) || wantedWords.isSubset(of: haveWords) else { return nil }
            // andere Einheit nur, wenn umrechenbar
            if item.unit != unit, convert(1, from: unit, to: item.unit, name: name) == nil { return nil }
            return (key, item.unit)
        }
        return matches.first { $0.unit == unit } ?? matches.first
    }

    /// Gewicht eines Stücks in Gramm für gängige Zutaten (zum Umrechnen zwischen g und Stück)
    private static let pieceGrams: [String: Double] = ["zwiebel": 150, "onion": 150, "knoblauch": 5, "garlic": 5,
                                                       "ei": 60, "egg": 60, "tomate": 100, "paprika": 150]

    private static func convert(_ amount: Double, from: String, to: String, name: String) -> Double? {
        let words = normalized(name).split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
        guard let grams = pieceGrams.first(where: { words.contains($0.key) })?.value else { return nil }
        switch (from, to) {
        case ("g", "pcs"): return amount / grams
        case ("pcs", "g"): return amount * grams
        default: return nil
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
        choices = result.sorted { Self.displayName($0.name).localizedStandardCompare(Self.displayName($1.name)) == .orderedAscending }
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

extension Notification.Name {
    /// Wechselt in den Tab „Einkauf“
    static let showShoppingList = Notification.Name("showShoppingList")
}


#Preview {
    NavigationStack { EventsView() }
}
