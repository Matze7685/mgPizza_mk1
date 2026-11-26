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
    var intro: String?            // Begrüßungstext / Anlass auf der Gästeseite
    var closed: Bool?             // true: Gäste sehen die Karte, können aber nicht mehr bestellen
}

/// Ein Abend/Anlass mit eigenem Gästelink. Die Liste liegt nur lokal in der App (Übersicht für den Gastgeber);
/// Gäste sehen immer nur ihren eigenen Abend.
struct GuestEvening: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var date: Date
    var intro: String = ""
    var guests: [String] = []
    var closed: Bool = false
    var orderCount: Int?
    var publishedAt: Date?
}

enum GuestEvenings {
    private static let key = "guestEvenings_v1"

    static var all: [GuestEvening] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([GuestEvening].self, from: data) else { return [] }
        return list
    }

    static var exists: Bool { UserDefaults.standard.data(forKey: key) != nil }

    static func save(_ list: [GuestEvening]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: key)
    }

    /// Abend anlegen oder aktualisieren; bekannte Werte (Bestellanzahl, Veröffentlichung) bleiben erhalten, wenn nicht neu gesetzt
    static func upsert(_ evening: GuestEvening) {
        var list = all
        if let i = list.firstIndex(where: { $0.id == evening.id }) {
            var merged = evening
            merged.orderCount = evening.orderCount ?? list[i].orderCount
            merged.publishedAt = evening.publishedAt ?? list[i].publishedAt
            list[i] = merged
        } else {
            list.append(evening)
        }
        save(list)
    }
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
    /// Nur lokal aus dem Server-Dokument gesetzt: Bestellung ist an ein Gästegerät gebunden
    var claimed: Bool? = nil
    var id: String { guest }
    private enum CodingKeys: String, CodingKey { case guest, lines, note }
}

/// Anonyme Firebase-Anmeldung des Gastgebers (einmal pro App-Installation, ohne Eingabe). Die Kennung (uid) steht als `hostUid`
/// am Abend; damit darf der Gastgeber jede Bestellung lesen, ändern, löschen oder freigeben (Firestore-Regeln, docs/README.md).
actor GuestHostAuth {
    static let shared = GuestHostAuth()
    private let refreshKey = "guestHostRefresh_v1"
    private let uidKey = "guestHostUid_v1"
    private var idToken = ""
    private var validUntil = Date.distantPast

    private func post(_ url: String, body: Data, type: String) async throws -> [String: Any] {
        guard let url = URL(string: url) else { throw GuestOrderError.auth }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(type, forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw code == 400 ? GuestOrderError.auth : GuestOrderError.server(code) }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func store(token: String?, refresh: String?, uid: String?, expires: String?) {
        idToken = token ?? ""
        validUntil = Date().addingTimeInterval(Double(expires ?? "") ?? 3600)
        if let refresh { UserDefaults.standard.set(refresh, forKey: refreshKey) }
        if let uid { UserDefaults.standard.set(uid, forKey: uidKey) }
    }

    /// Gültiges Token + uid (meldet sich bei Bedarf neu an; schlägt fehl, wenn „Anonym“ in Firebase nicht aktiviert ist)
    func session(apiKey: String) async throws -> (token: String, uid: String) {
        if !idToken.isEmpty, validUntil > Date().addingTimeInterval(60), let uid = UserDefaults.standard.string(forKey: uidKey) {
            return (idToken, uid)
        }
        if let refresh = UserDefaults.standard.string(forKey: refreshKey) {
            let form = "grant_type=refresh_token&refresh_token=\(refresh.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? refresh)"
            do {
                let json = try await post("https://securetoken.googleapis.com/v1/token?key=\(apiKey)", body: Data(form.utf8),
                                          type: "application/x-www-form-urlencoded")
                store(token: json["id_token"] as? String, refresh: json["refresh_token"] as? String,
                      uid: json["user_id"] as? String, expires: json["expires_in"] as? String)
                if let uid = UserDefaults.standard.string(forKey: uidKey), !idToken.isEmpty { return (idToken, uid) }
            } catch GuestOrderError.auth {
                // Token ungültig (HTTP 400): unten neue Kennung anlegen. Netzwerkfehler dagegen werden weitergereicht.
            }
            // Nur wenn sich das Token nicht erneuern lässt, wird eine neue Kennung angelegt (dann Abende neu veröffentlichen)
        }
        let json = try await post("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)",
                                  body: Data(#"{"returnSecureToken":true}"#.utf8), type: "application/json")
        store(token: json["idToken"] as? String, refresh: json["refreshToken"] as? String,
              uid: json["localId"] as? String, expires: json["expiresIn"] as? String)
        guard let uid = UserDefaults.standard.string(forKey: uidKey), !idToken.isEmpty else { throw GuestOrderError.auth }
        return (idToken, uid)
    }
}

enum GuestOrderError: LocalizedError {
    case notConfigured, forbidden, auth, server(Int)
    var errorDescription: String? {
        switch self {
        case .notConfigured: String(localized: "Enter the Firebase project ID, API key and page address first.")
        case .forbidden: String(localized: "Not allowed: this evening was published from another device, or the Firestore rules are not updated yet (see docs/README.md).")
        case .auth: String(localized: "Sign-in failed. Enable “Anonymous” under Authentication → Sign-in method in Firebase.")
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

    private var docRoot: String { "projects/\(project)/databases/(default)/documents" }

    private func string(_ value: String) -> [String: Any] { ["stringValue": value] }

    /// Anfrage an Firestore mit der Kennung des Gastgebers
    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard !apiKey.isEmpty else { throw GuestOrderError.notConfigured }
        var request = request
        request.setValue("Bearer \(try await GuestHostAuth.shared.session(apiKey: apiKey).token)", forHTTPHeaderField: "Authorization")
        return try await URLSession.shared.data(for: request)
    }

    private func write(_ method: String, _ path: String, fields: [String: Any]? = nil, mask: [String] = []) async throws {
        var query = ""
        for field in mask { query += "&updateMask.fieldPaths=\(field)" }
        var request = URLRequest(url: try url(path, query: query))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let fields { request.httpBody = try JSONSerialization.data(withJSONObject: ["fields": fields]) }
        let (_, response) = try await send(request)
        try check(response)
    }

    /// Speisekarte + Gäste hochladen (überschreibt die Karte unter derselben ID)
    func publish(_ event: GuestEvent, id: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(event), as: UTF8.self)
        let uid = try await GuestHostAuth.shared.session(apiKey: apiKey).uid
        try await write("PATCH", "events/\(id)", fields: ["data": string(json), "hostUid": string(uid)])
    }

    /// Push-Token dieses iPhones für Pizza-Push hinterlegen (Mac mini liest es mit seinem Dienstkonto, Gäste nicht)
    func savePushToken(_ token: String, sandbox: Bool) async throws {
        let uid = try await GuestHostAuth.shared.session(apiKey: apiKey).uid
        try await write("PATCH", "pushTokens/\(token)", fields: ["hostUid": string(uid), "sandbox": ["booleanValue": sandbox],
                                                              "updated": ["timestampValue": ISO8601DateFormatter().string(from: Date())]])
    }

    func deletePushToken(_ token: String) async throws {
        try await write("DELETE", "pushTokens/\(token)")
    }

    func fetchOrders(id: String) async throws -> [GuestOrder] {
        let (data, response) = try await send(URLRequest(url: try url("events/\(id)/orders", query: "&pageSize=300")))
        try check(response)
        struct List: Decodable {
            struct Doc: Decodable { var fields: [String: Field] }
            struct Field: Decodable { var stringValue: String? }
            var documents: [Doc]?
        }
        let list = try JSONDecoder().decode(List.self, from: data)
        return (list.documents ?? []).compactMap { doc in
            guard var order = doc.fields["data"]?.stringValue.flatMap({ try? JSONDecoder().decode(GuestOrder.self, from: Data($0.utf8)) })
            else { return nil }
            order.claimed = !(doc.fields["owner"]?.stringValue ?? "").isEmpty
            return order
        }
        .sorted { $0.guest.localizedCaseInsensitiveCompare($1.guest) == .orderedAscending }
    }

    /// Dokument-ID einer Bestellung, gleich wie `slug()` in docs/index.html
    private static let letters: ClosedRange<Unicode.Scalar> = "a"..."z"
    private static let digits: ClosedRange<Unicode.Scalar> = "0"..."9"

    static func slug(_ name: String) -> String {
        var out = ""
        var dash = false
        for scalar in name.lowercased().decomposedStringWithCompatibilityMapping.unicodeScalars {
            if Self.letters.contains(scalar) || Self.digits.contains(scalar) {
                if dash && !out.isEmpty { out.append("-") }
                dash = false
                out.unicodeScalars.append(scalar)
            } else {
                dash = true
            }
        }
        return out.isEmpty ? "gast" : out
    }

    /// Bestellung eines Gastes unter neuem Namen speichern und die alte entfernen (falls vorhanden). Das Gerät des Gasts bleibt zugeordnet.
    func renameOrder(id: String, from old: String, to new: String) async throws {
        let (data, response) = try await send(URLRequest(url: try url("events/\(id)/orders/\(Self.slug(old))")))
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return }
        try check(response)
        struct Doc: Decodable { struct Field: Decodable { var stringValue: String? }; var fields: [String: Field] }
        let fields = try JSONDecoder().decode(Doc.self, from: data).fields
        guard let json = fields["data"]?.stringValue,
              var order = try? JSONDecoder().decode(GuestOrder.self, from: Data(json.utf8)) else { return }
        order.guest = new
        let newJSON = String(decoding: try JSONEncoder().encode(order), as: UTF8.self)
        try await write("PATCH", "events/\(id)/orders/\(Self.slug(new))",
                        fields: ["data": string(newJSON), "owner": string(fields["owner"]?.stringValue ?? "")])
        if Self.slug(old) != Self.slug(new) { try await deleteOrder(id: id, guest: old) }
    }

    /// Als Gastgeber jede Bestellung löschen (fehlende Bestellung ist kein Fehler)
    func deleteOrder(id: String, guest: String) async throws {
        var request = URLRequest(url: try url("events/\(id)/orders/\(Self.slug(guest))"))
        request.httpMethod = "DELETE"
        let (_, response) = try await send(request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return }
        try check(response)
    }

    /// Bestellung für ein neues Gerät freigeben: Die Bestellung bleibt, das nächste Gerät, das sie speichert, übernimmt sie
    func releaseOrder(id: String, guest: String) async throws {
        try await write("PATCH", "events/\(id)/orders/\(Self.slug(guest))", fields: ["owner": string("")], mask: ["owner"])
    }

    private func check(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if http.statusCode == 403 { throw GuestOrderError.forbidden }
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
    @AppStorage("menuTitle") private var menuTitle = ""
    @AppStorage("menuDate") private var menuDate: Double = Date().timeIntervalSince1970
    @AppStorage("guestIntro") private var intro = ""
    @AppStorage("guestOrdersClosed") private var ordersClosed = false
    @AppStorage(GuestPush.enabledKey) private var pushEnabled = false
    @AppStorage(GuestPush.statusKey) private var pushStatus = ""
    @State private var orders: [GuestOrder] = []
    @State private var status = ""
    @State private var isBusy = false
    @State private var eveningCount = 0
    @State private var newGuest = ""
    @State private var renaming: String?
    @State private var renameText = ""
    @State private var removing: String?
    @State private var deletingOrder: String?

    private var guests: [String] {
        guestNames.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var guestLink: URL? { Self.link(pageURL: pageURL, id: eventID) }

    static func link(pageURL: String, id: String) -> URL? {
        guard !id.isEmpty, !pageURL.isEmpty, var parts = URLComponents(string: pageURL) else { return nil }
        parts.queryItems = [URLQueryItem(name: "e", value: id)]
        return parts.url
    }

    /// Der aktuelle Abend, wie er in der Übersicht gespeichert wird
    private var current: GuestEvening {
        GuestEvening(id: eventID, title: title, date: date, intro: intro, guests: guests, closed: ordersClosed)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline)
                        Text(date.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    TextField("Welcome text for guests (optional)", text: $intro, axis: .vertical)
                        .lineLimit(1...5)
                    Toggle("Orders closed", isOn: $ordersClosed)
                    NavigationLink {
                        GuestEveningsView(currentID: eventID, pageURL: pageURL, service: service) { switchTo($0) }
                    } label: {
                        LabeledContent("All evenings", value: "\(eveningCount)")
                    }
                    Button("New evening (new link)", systemImage: "sparkles") { startNewEvening() }
                } header: {
                    Text("Evening")
                } footer: {
                    Text("Title and date come from the menu. Each evening gets its own link; guests only ever see their own evening. Changes reach the guests after “Publish menu”.")
                }

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
                            .onSubmit(addGuests)
                        Button("Add", systemImage: "plus.circle.fill", action: addGuests)
                            .labelStyle(.iconOnly)
                            .disabled(newGuest.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Guests (\(guests.count))")
                } footer: {
                    Text("Tap a name to rename, swipe to remove. An existing order moves with the new name; removing a guest deletes their order. Several names at once: separate with commas.")
                }

                Section {
                    Button("Publish menu", systemImage: "icloud.and.arrow.up") { Task { await publish() } }
                        .disabled(isBusy)
                    if let link = guestLink {
                        // Als reiner Text teilen: Mit URL + message schicken manche Apps (WhatsApp, Nachrichten) nur die Nachricht
                        ShareLink(item: "🍕 \(title)\n\(link.absoluteString)") {
                            Label("Send guest link", systemImage: "link")
                        }
                        Link(destination: link) {
                            Label("Open guest page", systemImage: "safari")
                        }
                        Button("Copy guest link", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = link.absoluteString
                            status = String(localized: "Link copied.")
                        }
                        Text(link.absoluteString).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }

                Section {
                    Button("Fetch orders", systemImage: "icloud.and.arrow.down") { Task { await fetch() } }
                        .disabled(isBusy)
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
                    if !orders.isEmpty {
                        Button("Import into menu & toppings", systemImage: "square.and.arrow.down") {
                            importOrders()
                            dismiss()
                            NotificationCenter.default.post(name: .showShoppingList, object: nil)
                        }
                    }
                } header: {
                    Text("Orders")
                } footer: {
                    Text("Importing replaces the order counts in the menu. A lock means the order belongs to the guest's device. Swipe to release it (e.g. new phone) or delete it.")
                }

                Section {
                    Toggle("Push for guest orders", systemImage: "bell.badge", isOn: $pushEnabled)
                        .onChange(of: pushEnabled) { _, on in Task { on ? await GuestPush.enable() : await GuestPush.disable() } }
                    if pushEnabled && !pushStatus.isEmpty {
                        Text(pushStatus).font(.caption).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("A notification on this iPhone when a guest orders, changes or deletes an order. Needs Pizza-Push on the Mac mini (hosting/mac-mini/pizza-push).")
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
            .onAppear {
                if eventID.isEmpty { eventID = Self.newID() }
                // Erster Start mit Übersicht: den bisher genutzten Abend übernehmen
                if !GuestEvenings.exists {
                    var old = current
                    old.publishedAt = guests.isEmpty ? nil : .now
                    GuestEvenings.save(guests.isEmpty ? [] : [old])
                }
                eveningCount = GuestEvenings.all.count
            }
        }
    }

    static func newID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private var service: GuestOrderService { .init(project: project.trimmingCharacters(in: .whitespaces),
                                                   apiKey: apiKey.trimmingCharacters(in: .whitespaces)) }

    /// Neuer Abend mit neuem Link; der bisherige bleibt in der Übersicht erhalten
    private func startNewEvening() {
        if GuestEvenings.all.contains(where: { $0.id == eventID }) { GuestEvenings.upsert(current) }
        eventID = Self.newID()
        orders = []
        intro = ""
        ordersClosed = false
        status = String(localized: "New evening created. Set title and date in the menu, then publish.")
    }

    /// Zu einem anderen Abend aus der Übersicht wechseln (Link, Titel, Datum, Gäste, Text)
    private func switchTo(_ evening: GuestEvening) {
        if GuestEvenings.all.contains(where: { $0.id == eventID }) { GuestEvenings.upsert(current) }
        eventID = evening.id
        menuTitle = evening.title
        menuDate = evening.date.timeIntervalSince1970
        intro = evening.intro
        ordersClosed = evening.closed
        guestNames = evening.guests.joined(separator: "\n")
        orders = []
        status = String(localized: "Switched to “\(evening.title)”. Publishing sends the menu currently set up in the app.")
    }

    private func setGuests(_ list: [String]) {
        guestNames = list.joined(separator: "\n")
    }

    /// Ein oder mehrere Namen (mit Komma oder Zeilenumbruch getrennt) hinzufügen, ohne Doppelte
    private func addGuests() {
        var list = guests
        for name in newGuest.split(whereSeparator: { $0 == "," || $0 == "\n" }).map({ $0.trimmingCharacters(in: .whitespaces) })
        where !name.isEmpty && !list.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            list.append(name)
        }
        setGuests(list)
        newGuest = ""
    }

    /// Wurde der aktuelle Abend schon veröffentlicht? Dann Änderungen an der Gästeliste gleich hochladen.
    private var isPublished: Bool { GuestEvenings.all.contains { $0.id == eventID && $0.publishedAt != nil } }

    private func rename(_ old: String, to newName: String) async {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != old else { return }
        if guests.contains(where: { $0 != old && $0.caseInsensitiveCompare(name) == .orderedSame }) {
            status = String(localized: "“\(name)” is already on the list.")
            return
        }
        setGuests(guests.map { $0 == old ? name : $0 })
        if let i = orders.firstIndex(where: { $0.guest == old }) { orders[i].guest = name }
        guard isPublished else { return }
        do {
            try await service.renameOrder(id: eventID, from: old, to: name)
            await publish()
        } catch { status = error.localizedDescription }
    }

    private func remove(_ name: String) async {
        setGuests(guests.filter { $0 != name })
        orders.removeAll { $0.guest == name }
        guard isPublished else { return }
        do {
            try await service.deleteOrder(id: eventID, guest: name)
            await publish()
        } catch { status = error.localizedDescription }
    }

    private func release(_ name: String) async {
        do {
            try await service.releaseOrder(id: eventID, guest: name)
            orders = try await service.fetchOrders(id: eventID)
            status = String(localized: "Order of \(name) released. The next device that saves it takes it over.")
        } catch { status = error.localizedDescription }
    }

    private func deleteGuestOrder(_ name: String) async {
        do {
            try await service.deleteOrder(id: eventID, guest: name)
            orders.removeAll { $0.guest == name }
        } catch { status = error.localizedDescription }
    }

    private func publish() async {
        isBusy = true; defer { isBusy = false }
        let text = intro.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = GuestEvent(title: title, date: date, guests: guests, pizzas: pizzas.map { pizza in
            .init(name: pizza.name, info: pizza.info,
                  toppings: pizza.toppings.map { .init(name: $0.name, amount: $0.amount, unit: $0.unit) })
        }, intro: text.isEmpty ? nil : text, closed: ordersClosed ? true : nil)
        do {
            try await service.publish(event, id: eventID)
            var evening = current
            evening.publishedAt = .now
            GuestEvenings.upsert(evening)
            eveningCount = GuestEvenings.all.count
            status = guestLink == nil ? String(localized: "Published. Enter the guest page address to get the link.")
                                      : String(localized: "Published. Send the guest link.")
        } catch { status = error.localizedDescription }
    }

    /// Bestellungen in die Karte übernehmen und alle benötigten Zutaten auf die Einkaufsliste setzen
    private func importOrders() {
        MenuPizza.apply(orders: orders, to: pizzas, context: modelContext)
        try? modelContext.save()
        let all = (try? modelContext.fetch(FetchDescriptor<MenuPizza>())) ?? []
        let needed = MenuPizza.aggregatedToppings(of: all.filter(\.isOnMenu))
        ShoppingItem.replace(needed.map { ($0.name, MenuPizza.formatted($0.amount, unit: $0.unit)) },
                             source: title, in: modelContext)
        status = String(localized: "Orders imported, shopping list updated.")
    }

    private func fetch() async {
        isBusy = true; defer { isBusy = false }
        do {
            orders = try await service.fetchOrders(id: eventID)
            var evening = current
            evening.orderCount = orders.count
            GuestEvenings.upsert(evening)
            eveningCount = GuestEvenings.all.count
            status = String(localized: "\(orders.count) orders received.")
            // Direkt übernehmen und Einkaufsliste füllen; fehlt noch jemand, bleibt das Fenster offen
            if !orders.isEmpty {
                importOrders()
                if guests.allSatisfy({ name in orders.contains { $0.guest == name } }) {
                    dismiss()
                    NotificationCenter.default.post(name: .showShoppingList, object: nil)
                } else {
                    status = String(localized: "Orders imported, shopping list updated. Some guests are still missing.")
                }
            }
        } catch { status = error.localizedDescription }
    }
}

/// Übersicht aller Abende/Anlässe (nur für den Gastgeber): kommende und vergangene, mit Status und Anzahl Bestellungen
struct GuestEveningsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var currentID: String
    var pageURL: String
    var service: GuestOrderService
    var onSelect: (GuestEvening) -> Void

    @State private var evenings = GuestEvenings.all
    @State private var isRefreshing = false

    private var startOfToday: Date { Calendar.current.startOfDay(for: .now) }
    private var upcoming: [GuestEvening] { evenings.filter { $0.date >= startOfToday }.sorted { $0.date < $1.date } }
    private var past: [GuestEvening] { evenings.filter { $0.date < startOfToday }.sorted { $0.date > $1.date } }

    var body: some View {
        List {
            if evenings.isEmpty {
                Text("No evenings yet. Publish a menu to add one.").foregroundStyle(.secondary)
            }
            if !upcoming.isEmpty {
                Section("Upcoming") { ForEach(upcoming) { row($0) } }
            }
            if !past.isEmpty {
                Section("Past") { ForEach(past) { row($0) } }
            }
            Section {
            } footer: {
                Text("Tap an evening to work on it. Swipe right to open or copy its link. Removing it here only hides it in the app; its guest link keeps working.")
            }
        }
        .navigationTitle("All evenings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh orders", systemImage: "arrow.clockwise") { Task { await refresh() } }
                    .disabled(isRefreshing || evenings.isEmpty)
            }
        }
        .refreshable { await refresh() }
    }

    private func row(_ evening: GuestEvening) -> some View {
        Button {
            onSelect(evening)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(evening.title).font(.headline).foregroundStyle(.primary)
                    Spacer()
                    if evening.id == currentID {
                        Text("Current").font(.caption.bold()).foregroundStyle(.tint)
                    }
                }
                Text(evening.date.formatted(.dateTime.weekday(.abbreviated).day().month().year().hour().minute()))
                    .font(.caption).foregroundStyle(.secondary)
                Text(details(evening)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Remove", systemImage: "trash", role: .destructive) {
                evenings.removeAll { $0.id == evening.id }
                GuestEvenings.save(evenings)
            }
            .disabled(evening.id == currentID)
        }
        .swipeActions(edge: .leading) {
            if let link = GuestLinkSheet.link(pageURL: pageURL, id: evening.id) {
                Button("Open", systemImage: "safari") { openURL(link) }
                    .tint(.green)
                Button("Copy link", systemImage: "doc.on.doc") { UIPasteboard.general.string = link.absoluteString }
                    .tint(.blue)
            }
        }
    }

    private func details(_ evening: GuestEvening) -> String {
        var parts = [String(localized: "\(evening.guests.count) guests")]
        if let count = evening.orderCount { parts.append(String(localized: "\(count) orders")) }
        if evening.publishedAt == nil {
            parts.append(String(localized: "not published"))
        } else if evening.closed {
            parts.append(String(localized: "orders closed"))
        }
        return parts.joined(separator: " · ")
    }

    /// Bestellanzahl aller Abende neu abholen
    private func refresh() async {
        isRefreshing = true; defer { isRefreshing = false }
        for evening in evenings where evening.publishedAt != nil {
            guard let orders = try? await service.fetchOrders(id: evening.id) else { continue }
            var updated = evening
            updated.orderCount = orders.count
            GuestEvenings.upsert(updated)
        }
        evenings = GuestEvenings.all
    }
}
