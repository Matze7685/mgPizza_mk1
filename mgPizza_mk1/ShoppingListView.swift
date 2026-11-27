//
//  ShoppingListView.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]
    @State private var newName = ""
    @State private var newAmount = ""

    private var groups: [(source: String, items: [ShoppingItem])] {
        var order: [String] = []
        var map: [String: [ShoppingItem]] = [:]
        for item in items {
            if map[item.source] == nil { order.append(item.source) }
            map[item.source, default: []].append(item)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Item", text: $newName)
                    TextField("Amount", text: $newAmount)
                        .frame(width: 90)
                    Button("Add", systemImage: "plus.circle.fill") {
                        addItem()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if items.isEmpty {
                ContentUnavailableView("Nothing to buy", systemImage: "cart",
                                       description: Text("Add items here or from a dough / sauce recipe."))
            }
            // Ein Ordner pro Abend/Event bzw. Rezept (Quelle), in der Reihenfolge des Eintragens
            ForEach(groups, id: \.source) { group in
                Section {
                    ForEach(group.items) { item in
                        Button {
                            item.isDone.toggle()
                        } label: {
                            HStack {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isDone ? .green : .gray)
                                Text(LocalizedStringKey(item.name))
                                    .strikethrough(item.isDone)
                                Spacer()
                                Text(item.amount).foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        offsets.forEach { modelContext.delete(group.items[$0]) }
                    }
                } header: {
                    HStack {
                        Label(group.source.isEmpty ? String(localized: "Other") : group.source, systemImage: "folder")
                        Spacer()
                        Text("\(group.items.filter(\.isDone).count)/\(group.items.count)")
                    }
                }
            }
            if items.contains(where: { !$0.isDone }) {
                // Für Erinnerungen, Nachrichten oder WhatsApp: offene Einträge als Text, nach Quelle gruppiert
                ShareLink(item: shareText, subject: Text("Shopping list")) {
                    Label("Share list", systemImage: "square.and.arrow.up")
                }
            }
            if items.contains(where: \.isDone) {
                Button("Remove checked items", systemImage: "trash", role: .destructive) {
                    items.filter(\.isDone).forEach { modelContext.delete($0) }
                }
            }
        }
    }

    /// Noch nicht abgehakte Einträge als Text, z. B. „Salami-Abend:\n• Mozzarella – 500 g“
    private var shareText: String {
        groups.compactMap { group -> String? in
            let open = group.items.filter { !$0.isDone }
            guard !open.isEmpty else { return nil }
            let header = group.source.isEmpty ? String(localized: "Other") : group.source
            let lines = open.map { item in
                let name = NSLocalizedString(item.name, comment: "")   // z. B. „Flour“ → „Mehl“
                return item.amount.isEmpty ? "• \(name)" : "• \(name) – \(item.amount)"
            }
            return ([header + ":"] + lines).joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    private func addItem() {
        modelContext.insert(ShoppingItem(name: newName.trimmingCharacters(in: .whitespaces), amount: newAmount))
        newName = ""
        newAmount = ""
    }
}

/// Auswahl, welche Zutaten (und welche Mengen) auf die Einkaufsliste kommen.
struct ShoppingPickerSheet: View {
    struct Entry: Identifiable {
        let id = UUID()
        var name: String
        var amount: String
        var isSelected = false
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [Entry]
    let source: String

    init(items: [(String, String)], source: String) {
        _entries = State(initialValue: items.map { Entry(name: $0.0, amount: $0.1) })
        self.source = source
    }

    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text("Select what you need to buy. You can change the amount, e.g. to a package size.")) {
                    ForEach($entries) { $entry in
                        HStack {
                            Button {
                                entry.isSelected.toggle()
                            } label: {
                                Image(systemName: entry.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(entry.isSelected ? .green : .gray)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(LocalizedStringKey(entry.name)))
                            .accessibilityAddTraits(entry.isSelected ? .isSelected : [])
                            Text(LocalizedStringKey(entry.name))
                            Spacer()
                            TextField("Amount", text: $entry.amount)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add to shopping list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let selected = entries.filter(\.isSelected).map { ($0.name, $0.amount) }
                        ShoppingItem.add(selected, source: source, to: modelContext)
                        dismiss()
                    }
                    .disabled(!entries.contains(where: \.isSelected))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    ShoppingListView()
}
