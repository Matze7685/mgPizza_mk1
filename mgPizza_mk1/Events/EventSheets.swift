//
//  EventSheets.swift
//  mgPizza_mk1
//

import SwiftData
import SwiftUI

// Kleine Auswahl-Sheets der Anlass-Ansicht (Gäste übernehmen, neuer Anlass, Extras, Planungsart)

/// Gäste von früheren Anlässen übernehmen: alle eines Anlasses oder einzelne Namen
struct GuestPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var evenings: [GuestEvening]
    var existing: [String]
    var onAdd: ([String]) -> Void
    @State private var selected: Set<String> = []

    private func isNew(_ name: String) -> Bool {
        !existing.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Alle bekannten Namen, die noch nicht auf der Liste stehen
    private var names: [String] {
        var seen: [String] = []
        for name in evenings.sorted(by: { $0.date > $1.date }).flatMap(\.guests)
        where isNew(name) && !seen.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            seen.append(name)
        }
        return seen.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("All guests of an event") {
                    ForEach(evenings.filter { !$0.guests.isEmpty }.sorted { $0.date > $1.date }) { evening in
                        Button {
                            selected.formUnion(evening.guests.filter(isNew))
                        } label: {
                            LabeledContent(evening.title, value: "\(evening.guests.count)")
                        }
                        .foregroundStyle(.primary)
                    }
                }
                Section("Single guests") {
                    ForEach(names, id: \.self) { name in
                        Button {
                            if selected.contains(name) { selected.remove(name) } else { selected.insert(name) }
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(name) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(name) ? .green : .gray)
                                Text(name).foregroundStyle(.primary)
                            }
                        }
                    }
                    if names.isEmpty {
                        Text("All earlier guests are already on the list.").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Earlier guests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selected.count))") {
                        onAdd(names.filter(selected.contains))
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
}

/// Neuen Anlass anlegen: nur Name und Datum (Text optional). Danach geht es direkt zu Gästen und Speisekarte.
struct NewEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String, Date, String, Bool) -> Void

    @State private var title = ""
    @State private var fixed = false
    @State private var date = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: .now) ?? .now
    @State private var intro = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name of the event, e.g. Anna's 40th", text: $title)
                    DatePicker("Date", selection: $date)
                    if !fixed {
                        TextField("Welcome text for guests (optional)", text: $intro, axis: .vertical).lineLimit(1...4)
                    }
                }
                Section {
                    PlanModePicker(isFixed: $fixed)
                } footer: {
                    if fixed {
                        Text("Next you set how many of each pizza you make, e.g. 5× Salami and 5× Tuna. No guest list needed.")
                    } else {
                        Text("Next you add the guests and publish the menu.")
                    }
                }
            }
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(title.trimmingCharacters(in: .whitespaces), date,
                                 fixed ? "" : intro.trimmingCharacters(in: .whitespacesAndNewlines), fixed)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Feste Mengen: Zusatzzutaten für eine Sorte ankreuzen (Liste „Zusatzmengen pro Pizza“, Mengen kommen von dort)
struct ExtrasPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pizza: MenuPizza
    @State var selected: Set<String>
    var onSave: ([String]) -> Void

    /// Gespeicherte Zusatzzutaten ohne das, was schon auf der Pizza ist
    private var options: [String] {
        var seen = Set<String>()
        let own = pizza.toppings.map { $0.name.lowercased() }
        return (ExtraDefaults.all.map(\.name) + MenuPizza.alwaysOfferedExtras + selected.sorted())
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { name in
                let key = name.lowercased()
                guard !key.isEmpty, !seen.contains(key) else { return false }
                seen.insert(key)
                return !own.contains { $0 == key || $0.hasPrefix(key + " ") || $0.hasPrefix(key + "(") }
            }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            // Zwei Spalten, alphabetisch (wie auf der Gästeseite)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                          alignment: .leading, spacing: 14) {
                    ForEach(options, id: \.self) { name in
                        Button {
                            if selected.contains(name) { selected.remove(name) } else { selected.insert(name) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selected.contains(name) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3).foregroundStyle(selected.contains(name) ? .green : .gray)
                                Text(name).foregroundStyle(.primary).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Extras for \(pizza.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(options.filter { selected.contains($0) })
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Wie werden die Pizzen eines Anlasses geplant: Gäste bestellen selbst oder feste Mengen pro Sorte
struct PlanModePicker: View {
    @Binding var isFixed: Bool

    var body: some View {
        Picker("Pizzas", selection: $isFixed) {
            Text("Guests order").tag(false)
            Text("Fixed quantities").tag(true)
        }
        .pickerStyle(.segmented)
    }
}
