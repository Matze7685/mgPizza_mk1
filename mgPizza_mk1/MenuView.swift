//
//  MenuView.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

/// Tab „Anlass“: alle Anlässe auf einen Blick, neuen Anlass anlegen. Pizzen und Mengen liegen im Untermenü.
struct EventsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppKeys.menuEventID) private var eventID = ""
    @AppStorage(AppKeys.menuTitle) private var menuTitle = ""
    @AppStorage(AppKeys.menuDate) private var menuDate: Double = Date().timeIntervalSince1970
    @AppStorage(AppKeys.guestNames) private var guestNames = ""
    @AppStorage(AppKeys.guestIntro) private var intro = ""
    @AppStorage(AppKeys.guestOrdersClosed) private var ordersClosed = false
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
            if evenings.isEmpty {
                ContentUnavailableView("No events yet", systemImage: "party.popper",
                                       description: Text("A pizza night, a birthday, a team lunch: plan the pizzas, invite guests and collect their orders."))
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
        // Schnellaktion „Bestellungen“: aktuellen Anlass öffnen
        .onReceive(AppRouter.shared.$openEventID) { id in
            guard let id, !id.isEmpty else { return }
            reload()
            if let evening = evenings.first(where: { $0.id == id }) { openEvening = evening }
            AppRouter.shared.openEventID = nil
        }
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
            CurrentEvent.clear()   // Der gelöschte Anlass war der aktuelle: leer weitermachen
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
    @AppStorage(AppKeys.menuEventID) private var eventID = ""
    @AppStorage(AppKeys.menuTitle) private var menuTitle = ""
    @AppStorage(AppKeys.menuDate) private var menuDate: Double = Date().timeIntervalSince1970
    @AppStorage(AppKeys.guestNames) private var guestNames = ""
    @AppStorage(AppKeys.guestIntro) private var intro = ""
    @AppStorage(AppKeys.guestOrdersClosed) private var ordersClosed = false
    @AppStorage(AppKeys.menuHiddenPizzas) private var hiddenText = ""
    @AppStorage(AppKeys.menuEventDone) private var isDone = false
    @AppStorage(AppKeys.menuFixedMode) private var isFixed = false
    /// Feste Mengen: Extras pro Sorte als JSON (Pizza-Name -> Extras)
    @AppStorage(AppKeys.menuFixedExtras) private var fixedExtrasJSON = ""
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
    /// Pizzaabend-Assistent: vorbereitetes Teigrezept für diesen Anlass
    @State private var plannedDough: RecipeSetupData?
    @Query(sort: \RecipeSetupData.createdAt, order: .reverse) private var doughRecipes: [RecipeSetupData]
    @Environment(\.scenePhase) private var scenePhase

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
            // Solange der Anlass offen ist, jede Minute neue Bestellungen holen (kein Knopfdruck nötig)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                if isPublished && !isFixed && !isPast && !isBusy && scenePhase == .active {
                    await loadOrders(updateShopping: false)
                }
            }
        }
        // Nach unten ziehen: Bestellungen sofort holen
        .refreshable {
            if isPublished && !isFixed { await loadOrders(updateShopping: true) }
        }
        .sheet(item: $plannedDough) { recipe in
            RecipeContainerView(recipeSetupData: recipe,
                                isShowingNewRecipeView: Binding { plannedDough != nil } set: { if !$0 { plannedDough = nil } })
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
            Text("New orders arrive automatically every minute while this page is open, or pull down to refresh. Without guest page: enter the counts by hand under “Pizzas ordered”. Swipe an order to release it for a new phone or to delete it.")
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
            // Pizzaabend-Assistent: passender Teig mit Servierzeit = Anlass
            if roundCount > 0 {
                Button("Plan dough: \(roundCount) dough balls", systemImage: "wand.and.stars") { planDough(detroit: false) }
            }
            if detroitCount > 0 {
                Button("Plan dough: \(detroitCount) Detroit pans", systemImage: "wand.and.stars") { planDough(detroit: true) }
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

    /// Teig für diesen Anlass vorbereiten: bestes bisheriges Rezept des Stils als Vorlage,
    /// Anzahl aus den Bestellungen, Servieren zum Datum des Anlasses. Öffnet die Teig-Einstellungen zum Prüfen.
    private func planDough(detroit: Bool) {
        let sameStyle = doughRecipes.filter { $0.isDetroit == detroit }
        let base = sameStyle.max { ($0.rating, $0.createdAt) < ($1.rating, $1.createdAt) }
        let recipe = base?.copyAsTemplate() ?? RecipeSetupData()
        if base == nil && detroit {
            recipe.style = "detroit"
            recipe.waterRatio = 72
            recipe.saltRatio = 2.5
            recipe.oilRatio = 2
            recipe.kneadSteps = KneadStep.plan(forStyle: "detroit")
            recipe.applyDetroitWeight()
        }
        recipe.doughBallsCount = Double(max(detroit ? detroitCount : roundCount, 1))
        recipe.name = detroit ? "\(title) · Detroit" : title
        // Zeitplan nach Uhrzeit: Servieren = Anlass, raus aus dem Kühlschrank = Servieren − Raumgare
        let serving = max(date, Date().addingTimeInterval(3600))
        recipe.dateSelection = serving
        recipe.fridgeOutSelection = max(Date(), serving.addingTimeInterval(-recipe.roomTime * 3600))
        recipe.fridgeTimeMode = "OUT"
        recipe.roomTime = max(0, serving.timeIntervalSince(recipe.fridgeOutSelection) / 3600)
        plannedDough = recipe
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
        CurrentEvent.clear()
        resetOrderCounts()
        dismiss()
    }
}

#Preview {
    NavigationStack { EventsView() }
}
