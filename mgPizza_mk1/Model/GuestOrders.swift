//
//  GuestOrders.swift
//  mgPizza_mk1
//
//  Gäste-Speisekarte per Link: Der Link enthält die komplette Karte (Base64 im #-Teil),
//  die statische Seite `guest-menu/index.html` zeigt sie an und erzeugt eine Antwort-Nachricht
//  mit Import-Code. Kein eigener Server nötig.
//

import Foundation
import SwiftData

struct GuestOrder: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var orders: [String: Int] = [:]     // Pizzaname → Anzahl
    var note: String = ""

    var answered: Bool { !orders.isEmpty }
    var total: Int { orders.values.reduce(0, +) }
}

enum GuestMenuLink {
    static let guestsKey = "menuGuestsJSON"
    static let menuIDKey = "menuGuestID"
    static let pageURLKey = "guestPageURL"

    struct MenuPayload: Codable {
        struct Item: Codable { var n: String; var i: String; var t: String }
        var v = 1
        var id: String
        var t: String
        var d: Double
        var g: [String]
        var p: [Item]
    }

    struct ReplyPayload: Codable {
        var v = 1
        var id: String
        var g: String
        var o: [String: Int]
        var n: String = ""
    }

    // MARK: Base64url
    static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        var s = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        guard let data = Data(base64Encoded: s) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: Link
    static func menuID() -> String {
        if let id = UserDefaults.standard.string(forKey: menuIDKey), !id.isEmpty { return id }
        let id = String(UUID().uuidString.prefix(8))
        UserDefaults.standard.set(id, forKey: menuIDKey)
        return id
    }

    /// Basis-URL der Gästeseite + Karte im #-Teil (wird nie an einen Server gesendet)
    static func menuURL(pageURL: String, title: String, date: Date, guests: [String], pizzas: [MenuPizza]) -> URL? {
        guard !pageURL.isEmpty else { return nil }
        let payload = MenuPayload(id: menuID(), t: title, d: date.timeIntervalSince1970, g: guests,
                                  p: pizzas.map { .init(n: $0.name, i: $0.info, t: $0.toppingsText) })
        guard let code = encode(payload) else { return nil }
        let base = pageURL.components(separatedBy: "#").first ?? pageURL
        return URL(string: "\(base)#m=\(code)")
    }

    // MARK: Gästeliste
    static func loadGuests() -> [GuestOrder] {
        guard let data = UserDefaults.standard.data(forKey: guestsKey),
              let list = try? JSONDecoder().decode([GuestOrder].self, from: data) else { return [] }
        return list
    }

    static func saveGuests(_ guests: [GuestOrder]) {
        if let data = try? JSONEncoder().encode(guests) { UserDefaults.standard.set(data, forKey: guestsKey) }
    }

    /// Bestellmenge je Pizza = Summe über alle Gäste
    static func applyTotals(guests: [GuestOrder], to pizzas: [MenuPizza]) {
        for pizza in pizzas {
            pizza.orderCount = guests.reduce(0) { $0 + ($1.orders[pizza.name] ?? 0) }
        }
    }

    // MARK: Import
    enum ImportResult { case imported(String), wrongMenu, invalid }

    /// Findet den Code in einer Nachricht ("mgpizza://order?r=…" oder "…#r=…") bzw. einem reinen Code
    static func replyPayload(from text: String) -> ReplyPayload? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: #"[?#&]r=([A-Za-z0-9_-]+)"#, options: .regularExpression) {
            let code = trimmed[range].dropFirst(3)
            return decode(ReplyPayload.self, from: String(code))
        }
        return decode(ReplyPayload.self, from: trimmed)
    }

    @MainActor
    static func importReply(_ text: String, context: ModelContext) -> ImportResult {
        guard let reply = replyPayload(from: text), !reply.g.isEmpty else { return .invalid }
        guard reply.id == menuID() else { return .wrongMenu }
        var guests = loadGuests()
        if let index = guests.firstIndex(where: { $0.name.caseInsensitiveCompare(reply.g) == .orderedSame }) {
            guests[index].orders = reply.o
            guests[index].note = reply.n
        } else {
            guests.append(GuestOrder(name: reply.g, orders: reply.o, note: reply.n))
        }
        saveGuests(guests)
        if let pizzas = try? context.fetch(FetchDescriptor<MenuPizza>()) {
            applyTotals(guests: guests, to: pizzas.filter(\.isOnMenu))
        }
        return .imported(reply.g)
    }
}
