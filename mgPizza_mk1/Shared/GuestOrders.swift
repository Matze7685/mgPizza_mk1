//
//  GuestOrders.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

/// Gäste-Speisekarte online: Die App lädt Karte + Gästeliste nach Firebase (Firestore, REST), die Gäste öffnen
/// die Webseite (docs/index.html), tragen sich ein und wählen Pizzen und Zutaten. Die App holt die Bestellungen ab.
/// Einrichtung: docs/README.md

struct GuestEvent: Codable {
    struct PizzaDTO: Codable {
        var name: String
        var info: String
        var toppings: [Topping]
    }
    struct Topping: Codable {
        var name: String
        var amount: Double
        var unit: String
    }
    var title: String
    var date: Date
    var guests: [String]
    var pizzas: [PizzaDTO]
}

struct GuestOrder: Codable, Identifiable {
    struct Line: Codable {
        var name: String          // Pizza
        var count: Int
        var without: [String]     // abgewählte Zutaten
        var custom: [GuestEvent.Topping]?   // nur bei „Eigene Pizza“: gewählte Zutaten
        var extra: [String]?      // freie Zusatzzutaten des Gastes
    }
    var guest: String
    var lines: [Line]
    var note: String?
    var id: String { guest }
}

enum GuestOrderError: LocalizedError {
    case notConfigured, server(Int)
    var errorDescription: String? {
        switch self {
        case .notConfigured: String(localized: "Enter the Firebase project ID, API key and page address first.")
        case .server(let code): String(localized: "Server error \(code). Check project ID, API key and the Firestore rules.")
        }
    }
}

/// Standardmenge pro Pizza für Zusatzzutaten, die Gäste frei eintippen (z. B. „Ananas“ -> 50 g)
struct ExtraAmount: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var amount: Double
    var unit: String = "g"
}

enum ExtraDefaults {
    private static let key = "extraDefaults_v1"

    static let builtIn: [ExtraAmount] = [
        .init(name: "Ananas", amount: 50), .init(name: "Champignons", amount: 60), .init(name: "Pilze", amount: 60),
        .init(name: "Oliven", amount: 15), .init(name: "Mais", amount: 30), .init(name: "Paprika", amount: 40),
        .init(name: "Speck", amount: 40), .init(name: "Zwiebel", amount: 20), .init(name: "Rucola", amount: 15),
        .init(name: "Salami", amount: 50), .init(name: "Schinken", amount: 50), .init(name: "Thunfisch", amount: 60),
        .init(name: "Knoblauch", amount: 1, unit: "pcs"), .init(name: "Parmesan", amount: 15),
        .init(name: "Gorgonzola", amount: 30), .init(name: "Mozzarella", amount: 50), .init(name: "Basilikum", amount: 3, unit: "pcs"),
        .init(name: "Artischocken", amount: 40), .init(name: "Peperoni", amount: 30), .init(name: "Dönerfleisch", amount: 60),
        .init(name: "Tomaten", amount: 50), .init(name: "Ei", amount: 1, unit: "pcs"), .init(name: "Chili", amount: 0.25, unit: "tsp"),
    ]

    static var all: [ExtraAmount] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([ExtraAmount].self, from: data) else { return builtIn }
        return list
    }

    static func save(_ list: [ExtraAmount]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: key)
    }

    /// Menge pro Pizza für einen frei eingetippten Namen; unbekannt -> 1 Stück
    static func amount(for name: String) -> (amount: Double, unit: String) {
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !wanted.isEmpty else { return (1, "pcs") }
        let list = all.filter { !$0.name.isEmpty }
        let match = list.first { $0.name.lowercased() == wanted }
            ?? list.first { wanted.contains($0.name.lowercased()) || $0.name.lowercased().contains(wanted) }
        return match.map { ($0.amount, $0.unit) } ?? (1, "pcs")
    }
}

struct ExtraDefaultsEditor: View {
    @State private var items = ExtraDefaults.all

    var body: some View {
        List {
            Section {
                ForEach($items) { $item in
                    HStack {
                        TextField("Ingredient", text: $item.name)
                        TextField("Amount", value: $item.amount, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Picker("Unit", selection: $item.unit) {
                            ForEach(["g", "ml", "pcs", "tsp"], id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                .onDelete { items.remove(atOffsets: $0) }
                Button("Add ingredient", systemImage: "plus") { items.append(ExtraAmount(name: "", amount: 30)) }
                Button("Restore defaults", systemImage: "arrow.uturn.backward") { items = ExtraDefaults.builtIn }
            } footer: {
                Text("Amount per pizza. Used when guests type their own extra ingredients. Unknown ingredients count as 1 piece.")
            }
        }
        .navigationTitle("Extra amounts")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: items) { _, new in ExtraDefaults.save(new) }
    }
}

struct GuestOrderService {
    var project: String
    var apiKey: String

    private func url(_ path: String, query: String = "") throws -> URL {
        guard !project.isEmpty, !apiKey.isEmpty,
              let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(project)/databases/(default)/documents/\(path)?key=\(apiKey)\(query)")
        else { throw GuestOrderError.notConfigured }
        return url
    }

    /// Speisekarte + Gäste hochladen (überschreibt die Karte unter derselben ID)
    func publish(_ event: GuestEvent, id: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(event), as: UTF8.self)
        var request = URLRequest(url: try url("events/\(id)"))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["fields": ["data": ["stringValue": json]]])
        let (_, response) = try await URLSession.shared.data(for: request)
        try check(response)
    }

    func fetchOrders(id: String) async throws -> [GuestOrder] {
        let (data, response) = try await URLSession.shared.data(from: try url("events/\(id)/orders", query: "&pageSize=300"))
        try check(response)
        struct List: Decodable {
            struct Doc: Decodable { var fields: [String: Field] }
            struct Field: Decodable { var stringValue: String? }
            var documents: [Doc]?
        }
        let list = try JSONDecoder().decode(List.self, from: data)
        return (list.documents ?? []).compactMap { doc in
            doc.fields["data"]?.stringValue.flatMap { try? JSONDecoder().decode(GuestOrder.self, from: Data($0.utf8)) }
        }
        .sorted { $0.guest.localizedCaseInsensitiveCompare($1.guest) == .orderedAscending }
    }

    private func check(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GuestOrderError.server(http.statusCode)
        }
    }
}

extension MenuPizza {
    /// Bestellungen der Gäste übernehmen: Anzahl + abgewählte Zutaten; eigene Pizzen werden als eigene Einträge angelegt
    static func apply(orders: [GuestOrder], to pizzas: [MenuPizza], context: ModelContext) {
        for pizza in pizzas {
            var count = 0
            var removed: [String: Int] = [:]
            var extras: [String: Int] = [:]
            for line in orders.flatMap(\.lines) where line.custom == nil && line.name == pizza.name {
                count += line.count
                for name in line.without { removed[name, default: 0] += line.count }
                for name in line.extra ?? [] { extras[name, default: 0] += line.count }
            }
            pizza.orderCount = count
            pizza.removedToppings = removed
            pizza.guestExtras = extras
        }
        // Frühere eigene Pizzen ersetzen
        if let old = try? context.fetch(FetchDescriptor<MenuPizza>(predicate: #Predicate { $0.isGuestCustom == true })) {
            old.forEach { context.delete($0) }
        }
        var index = 1000
        for order in orders {
            for line in order.lines {
                guard let custom = line.custom, line.count > 0 else { continue }
                let pizza = MenuPizza(name: String(localized: "Custom pizza – \(order.guest)"),
                                      toppings: custom.map { Topping(name: $0.name, amount: $0.amount, unit: $0.unit) }
                                          + (line.extra ?? []).map { extra in
                                              let standard = ExtraDefaults.amount(for: extra)
                                              return Topping(name: extra, amount: standard.amount, unit: standard.unit)
                                          },
                                      sortIndex: index)
                pizza.isGuestCustom = true
                pizza.orderCount = line.count
                context.insert(pizza)
                index += 1
            }
        }
    }
}

struct GuestLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var title: String
    var date: Date
    var pizzas: [MenuPizza]          // nur die auf der Karte

    @AppStorage("fbProject") private var project = ""
    @AppStorage("fbKey") private var apiKey = ""
    @AppStorage("guestPageURL") private var pageURL = ""
    @AppStorage("guestNames") private var guestNames = ""
    @AppStorage("menuEventID") private var eventID = ""
    @State private var orders: [GuestOrder] = []
    @State private var status = ""
    @State private var isBusy = false

    private var guests: [String] {
        guestNames.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var guestLink: URL? {
        guard !eventID.isEmpty, var parts = URLComponents(string: pageURL), !pageURL.isEmpty else { return nil }
        parts.queryItems = [URLQueryItem(name: "e", value: eventID)]
        return parts.url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("One name per line", text: $guestNames, axis: .vertical)
                        .lineLimit(3...12)
                } header: {
                    Text("Guests tonight")
                } footer: {
                    Text("Guests pick their name on the page, then choose pizzas and toppings.")
                }

                Section {
                    Button("Publish menu", systemImage: "icloud.and.arrow.up") { Task { await publish() } }
                        .disabled(isBusy)
                    if let link = guestLink {
                        // Als reiner Text teilen: Mit URL + message schicken manche Apps (WhatsApp, Nachrichten) nur die Nachricht
                        ShareLink(item: "🍕 \(title)\n\(link.absoluteString)") {
                            Label("Send guest link", systemImage: "link")
                        }
                        Button("Copy guest link", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = link.absoluteString
                            status = String(localized: "Link copied.")
                        }
                        Text(link.absoluteString).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Button("New evening (new link, clears orders)", systemImage: "sparkles", role: .destructive) {
                        eventID = Self.newID()
                        orders = []
                        status = String(localized: "New link created. Publish the menu again.")
                    }
                }

                Section {
                    Button("Fetch orders", systemImage: "icloud.and.arrow.down") { Task { await fetch() } }
                        .disabled(isBusy)
                    ForEach(orders) { order in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(order.guest).font(.headline)
                            Text(order.lines.map { "\($0.count)× \($0.name)" + ($0.custom.map { " (\($0.map(\.name).joined(separator: ", ")))" } ?? "") + (($0.extra ?? []).isEmpty ? "" : " + \($0.extra!.joined(separator: ", "))") + ($0.without.isEmpty ? "" : " (\(String(localized: "without")) \($0.without.joined(separator: ", ")))") }
                                .joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    let missing = guests.filter { name in !orders.contains { $0.guest == name } }
                    if !orders.isEmpty && !missing.isEmpty {
                        Text("Still missing: \(missing.joined(separator: ", "))").font(.caption).foregroundStyle(.orange)
                    }
                    if !orders.isEmpty {
                        Button("Import into menu & toppings", systemImage: "square.and.arrow.down") {
                            MenuPizza.apply(orders: orders, to: pizzas, context: modelContext)
                            status = String(localized: "Orders imported. The needed toppings are updated below.")
                            dismiss()
                        }
                    }
                } header: {
                    Text("Orders")
                } footer: {
                    Text("Importing replaces the order counts in the menu.")
                }

                Section {
                    NavigationLink("Extra amounts per pizza") { ExtraDefaultsEditor() }
                } footer: {
                    Text("How much of an ingredient one pizza needs when a guest types it in as an extra.")
                }

                Section {
                    TextField("Firebase project ID", text: $project).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Firebase API key", text: $apiKey).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Guest page address (https://…)", text: $pageURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Setup (once)")
                } footer: {
                    Text("Steps: see docs/README.md in the repository.")
                }

                if !status.isEmpty {
                    Section { Text(status).font(.callout) }
                }
            }
            .navigationTitle("Guest link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { if eventID.isEmpty { eventID = Self.newID() } }
        }
    }

    static func newID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private var service: GuestOrderService { .init(project: project.trimmingCharacters(in: .whitespaces),
                                                   apiKey: apiKey.trimmingCharacters(in: .whitespaces)) }

    private func publish() async {
        isBusy = true; defer { isBusy = false }
        let event = GuestEvent(title: title, date: date, guests: guests, pizzas: pizzas.map { pizza in
            .init(name: pizza.name, info: pizza.info,
                  toppings: pizza.toppings.map { .init(name: $0.name, amount: $0.amount, unit: $0.unit) })
        })
        do {
            try await service.publish(event, id: eventID)
            status = guestLink == nil ? String(localized: "Published. Enter the guest page address to get the link.")
                                      : String(localized: "Published. Send the guest link.")
        } catch { status = error.localizedDescription }
    }

    private func fetch() async {
        isBusy = true; defer { isBusy = false }
        do {
            orders = try await service.fetchOrders(id: eventID)
            status = String(localized: "\(orders.count) orders received.")
        } catch { status = error.localizedDescription }
    }
}
