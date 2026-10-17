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

#Preview {
    ShoppingListView()
}
