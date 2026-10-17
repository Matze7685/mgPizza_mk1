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
            Section {
                ForEach(items) { item in
                    Button {
                        item.isDone.toggle()
                    } label: {
                        HStack {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isDone ? .green : .gray)
                            VStack(alignment: .leading) {
                                Text(LocalizedStringKey(item.name))
                                    .strikethrough(item.isDone)
                                if !item.source.isEmpty {
                                    Text(item.source).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(item.amount).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { offsets in
                    offsets.forEach { modelContext.delete(items[$0]) }
                }
            }
            if items.contains(where: \.isDone) {
                Button("Remove checked items", systemImage: "trash", role: .destructive) {
                    items.filter(\.isDone).forEach { modelContext.delete($0) }
                }
            }
        }
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
