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
    /// Pizzen, die bei diesem Anlass nicht auf der Karte stehen (Namen)
    var hiddenPizzas: [String]?

    /// Von Hand als erledigt markiert
    var done: Bool?

    /// Anlass vorbei: als erledigt markiert oder Datum liegt vor heute (Wechsel automatisch um Mitternacht)
    var isPast: Bool { done == true || date < Calendar.current.startOfDay(for: .now) }
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

    static func remove(id: String) {
        save(all.filter { $0.id != id })
    }

    static func newID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// Adresse der Gästeseite (Einstellung, sonst die feste Adresse)
    static var pageURL: String {
        let value = (UserDefaults.standard.string(forKey: "guestPageURL") ?? "").trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? GuestFirebaseDefaults.pageURL : value
    }

    static func link(id: String) -> URL? {
        guard !id.isEmpty, var parts = URLComponents(string: pageURL) else { return nil }
        parts.queryItems = [URLQueryItem(name: "e", value: id)]
        return parts.url
    }
}

extension GuestOrderService {
    /// Mit den gespeicherten Firebase-Werten (leer = feste Werte)
    static var current: GuestOrderService {
        func value(_ key: String, _ fallback: String) -> String {
            let text = (UserDefaults.standard.string(forKey: key) ?? "").trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? fallback : text
        }
        return GuestOrderService(project: value("fbProject", GuestFirebaseDefaults.project),
                                 apiKey: value("fbKey", GuestFirebaseDefaults.apiKey))
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
    /// Später zur Standardliste dazugekommene Zutaten einmalig in gespeicherte Listen übernehmen
    private static let addedKey = "extraDefaultsAdded_v2"
    private static let addedLater = ["Tomatensauce"]

    static let builtIn: [ExtraAmount] = [
        .init(name: "Tomatensauce", amount: 80),
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
              var list = try? JSONDecoder().decode([ExtraAmount].self, from: data) else { return builtIn }
        if !UserDefaults.standard.bool(forKey: addedKey) {
            let have = Set(list.map { normalized($0.name) })
            for name in addedLater where !have.contains(normalized(name)) {
                if let item = builtIn.first(where: { $0.name == name }) { list.insert(item, at: 0) }
            }
            save(list)
            UserDefaults.standard.set(true, forKey: addedKey)
        }
        return list
    }

    static func save(_ list: [ExtraAmount]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: key)
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "soße", with: "sauce").replacingOccurrences(of: "sosse", with: "sauce")
    }

    /// Menge pro Pizza für einen frei eingetippten Namen; unbekannt -> 1 Stück.
    /// Genauer Name zuerst, sonst der längste passende Name („Tomatensauce“ vor „Tomaten“).
    static func amount(for name: String) -> (amount: Double, unit: String) {
        let wanted = normalized(name)
        guard !wanted.isEmpty else { return (1, "pcs") }
        let list = all.filter { !normalized($0.name).isEmpty }
        let match = list.first { normalized($0.name) == wanted }
            ?? list.filter { wanted.contains(normalized($0.name)) || normalized($0.name).contains(wanted) }
                .max { normalized($0.name).count < normalized($1.name).count }
        return match.map { ($0.amount, $0.unit) } ?? (1, "pcs")
    }
}

struct ExtraDefaultsEditor: View {
    @State private var items = ExtraDefaults.all

    var body: some View {
        List {
            Section {
                ForEach($items) { $item in
                    ExtraAmountRow(item: $item)
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

/// Eine Zeile im Mengen-Editor.
private struct ExtraAmountRow: View {
    @Binding var item: ExtraAmount

    var body: some View {
        HStack {
            TextField("Ingredient", text: $item.name)
            AmountField(value: $item.amount)
            Picker("Unit", selection: $item.unit) {
                ForEach(["g", "ml", "pcs", "tsp"], id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

/// Mengenfeld, das die Zahl schon beim Tippen übernimmt. Ein Zahlenfeld mit Format
/// (`TextField(value:format:)`) speichert erst nach „Return“, den es auf dem Ziffernblock nicht gibt,
/// deshalb gingen eingetippte Mengen verloren. Komma und Punkt gehen beide.
struct AmountField: View {
    @Binding var value: Double
    var width: CGFloat = 60
    @State private var text = ""

    var body: some View {
        TextField("Amount", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: width)
            .onAppear { text = Self.format(value) }
            .onChange(of: text) { _, new in
                if let parsed = Self.parse(new), parsed != value { value = parsed }
            }
            // Wert von außen geändert (z. B. „Standard wiederherstellen“, andere Pizza-Anzahl)
            .onChange(of: value) { _, new in
                if let parsed = Self.parse(text), abs(parsed - new) < 0.005 { return }
                text = Self.format(new)
            }
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    private static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value >= 0 else { return nil }
        return value
    }
}

/// Das Firebase-Projekt dieser App (gleiche Werte wie oben in docs/index.html, der Web-API-Key ist öffentlich).
/// Muss nicht mehr eingetragen werden; nur wer ein eigenes Projekt nutzt, ändert die Felder im Gästelink-Fenster.
enum GuestFirebaseDefaults {
    static let project = "mgpizza-app"
    static let apiKey = "AIzaSyCea9qvMqHYYgk8dAe5hGcDGMuobLgP6Tc"
    /// Feste Adresse der Gästeseite (Mac mini). Pro Anlass hängt die App nur `?e=…` an, die Adresse bleibt immer gleich.
    static let pageURL = "https://guderjahn.homeip.net/"
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

    /// Anlass in Firebase löschen (die Gästeseite zeigt ihn danach nicht mehr)
    func deleteEvent(id: String) async throws {
        var request = URLRequest(url: try url("events/\(id)"))
        request.httpMethod = "DELETE"
        let (_, response) = try await send(request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return }
        try check(response)
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
