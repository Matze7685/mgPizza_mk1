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
    /// Bestellungen der Gäste in die Speisekarte übernehmen (Anzahl + abgewählte Zutaten)
    static func apply(orders: [GuestOrder], to pizzas: [MenuPizza]) {
        for pizza in pizzas {
            var count = 0
            var removed: [String: Int] = [:]
            for line in orders.flatMap(\.lines) where line.name == pizza.name {
                count += line.count
                for name in line.without { removed[name, default: 0] += line.count }
            }
            pizza.orderCount = count
            pizza.removedToppings = removed
        }
    }
}

struct GuestLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
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
                        ShareLink(item: link, message: Text("🍕 \(title)")) {
                            Label("Send guest link", systemImage: "link")
                        }
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
                            Text(order.lines.map { "\($0.count)× \($0.name)" + ($0.without.isEmpty ? "" : " (\(String(localized: "without")) \($0.without.joined(separator: ", ")))") }
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
                            MenuPizza.apply(orders: orders, to: pizzas)
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
