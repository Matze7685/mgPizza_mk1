//
//  GuestMenuView.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI
import UIKit

/// Gäste für den Abend eintragen, Link teilen, Antworten importieren.
struct GuestMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MenuPizza.sortIndex) private var pizzas: [MenuPizza]
    @AppStorage("menuTitle") private var menuTitle = ""
    @AppStorage("menuDate") private var menuDate: Double = Date().timeIntervalSince1970
    @AppStorage(GuestMenuLink.pageURLKey) private var pageURL = ""
    @State private var guests: [GuestOrder] = GuestMenuLink.loadGuests()
    @State private var newName = ""
    @State private var pasteText = ""
    @State private var message: String?

    private var title: String { menuTitle.isEmpty ? String(localized: "Pizza night") : menuTitle }

    private var link: URL? {
        GuestMenuLink.menuURL(pageURL: pageURL, title: title, date: Date(timeIntervalSince1970: menuDate),
                              guests: guests.map(\.name), pizzas: pizzas.filter(\.isOnMenu))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(guests) { guest in
                        HStack {
                            Image(systemName: guest.answered ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(guest.answered ? .green : .gray)
                            VStack(alignment: .leading) {
                                Text(guest.name)
                                if guest.answered {
                                    Text(summary(of: guest)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { guests.remove(atOffsets: $0); persist() }
                    HStack {
                        TextField("Guest name", text: $newName).onSubmit(addGuest)
                        Button("Add", action: addGuest).disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Guests")
                } footer: {
                    Text("Add your guests first, then send the link. Guests pick their name and pizzas.")
                }

                Section {
                    TextField("https://…/guest-menu/", text: $pageURL)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if let link {
                        ShareLink(item: link, subject: Text(title)) {
                            Label("Send guest link", systemImage: "link")
                        }
                    }
                } header: {
                    Text("Guest page")
                } footer: {
                    Text("Address of the hosted guest page (file guest-menu/index.html in the repository). The menu is part of the link, no server needed.")
                }

                Section {
                    Button("Import reply from clipboard", systemImage: "doc.on.clipboard") {
                        importText(UIPasteboard.general.string ?? "")
                    }
                    TextField("Or paste a reply here", text: $pasteText, axis: .vertical).lineLimit(1...3)
                    Button("Import", systemImage: "square.and.arrow.down") { importText(pasteText); pasteText = "" }
                        .disabled(pasteText.isEmpty)
                } header: {
                    Text("Replies")
                } footer: {
                    Text("Tapping the link in a guest's reply opens it directly in this app.")
                }
            }
            .navigationTitle("Guest menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                let latest = GuestMenuLink.loadGuests()
                if latest != guests { guests = latest }
            }
        }
    }

    private func summary(of guest: GuestOrder) -> String {
        var text = guest.orders.sorted { $0.key < $1.key }.map { "\($0.value)× \($0.key)" }.joined(separator: ", ")
        if !guest.note.isEmpty { text += " – \(guest.note)" }
        return text
    }

    private func addGuest() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        guests.append(GuestOrder(name: name))
        newName = ""
        persist()
    }

    private func persist() { GuestMenuLink.saveGuests(guests) }

    private func importText(_ text: String) {
        switch GuestMenuLink.importReply(text, context: modelContext) {
        case .imported(let name):
            guests = GuestMenuLink.loadGuests()
            message = String(localized: "Order of \(name) imported.")
        case .wrongMenu: message = String(localized: "This reply belongs to a different menu.")
        case .invalid: message = String(localized: "No order found in this text.")
        }
    }
}
