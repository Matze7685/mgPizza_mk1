//
//  OrdersFoldView.swift
//  mgPizza_mk1
//
//  Bestellübersicht für ein faltbares iPhone in der Laptop-Stellung:
//  obere Bildschirmhälfte = große Bestellübersicht zum Ablesen, untere Hälfte = Bedienung.
//  Die Teilung liegt genau in der Bildschirmmitte (dort, wo der Knick ist). Auf normalen
//  iPhones funktioniert dieselbe Ansicht einfach als geteilter Bildschirm.
//

import SwiftData
import SwiftUI

struct OrdersFoldView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MenuPizza.sortIndex) private var pizzas: [MenuPizza]

    @AppStorage("fbProject") private var project = GuestFirebaseDefaults.project
    @AppStorage("fbKey") private var apiKey = GuestFirebaseDefaults.apiKey
    @AppStorage("menuEventID") private var eventID = ""
    @AppStorage("menuTitle") private var menuTitle = ""
    /// Abstand für den Knick in der Mitte (Punkte); dort steht kein Inhalt
    @AppStorage("foldHingeGap") private var hingeGap: Double = 24
    /// Halbbildschirme tauschen (falls das Gerät andersherum gehalten wird)
    @AppStorage("foldSwapHalves") private var swapHalves = false

    enum TopMode: Hashable { case pizzas, guests }
    @State private var topMode: TopMode = .pizzas
    @State private var orders: [GuestOrder] = []
    @State private var status = ""
    @State private var isBusy = false
    /// Schon gebackene Pizzen je Pizza (nur solange die Ansicht offen ist)
    @State private var baked: [PersistentIdentifier: Int] = [:]

    private var onMenu: [MenuPizza] { pizzas.filter(\.isOnMenu) }
    private var ordered: [MenuPizza] { onMenu.filter { $0.orderCount > 0 } }
    private var totalOrders: Int { onMenu.reduce(0) { $0 + $1.orderCount } }
    private var totalBaked: Int { ordered.reduce(0) { $0 + min(baked[$1.persistentModelID] ?? 0, $1.orderCount) } }
    private var roundCount: Int { onMenu.filter { !$0.isDetroit }.reduce(0) { $0 + $1.orderCount } }
    private var detroitCount: Int { onMenu.filter(\.isDetroit).reduce(0) { $0 + $1.orderCount } }
    private var title: String { menuTitle.isEmpty ? String(localized: "Pizza night") : menuTitle }

    var body: some View {
        GeometryReader { geo in
            // Gesamthöhe inkl. Statusleiste/Home-Indikator, damit die Teilung genau auf dem Knick liegt
            let full = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let half = max(0, (full - hingeGap) / 2)
            let firstHeight = max(0, half - geo.safeAreaInsets.top)
            let secondHeight = max(0, half - geo.safeAreaInsets.bottom)
            VStack(spacing: 0) {
                Group {
                    if swapHalves { controls } else { overview }
                }
                .frame(height: firstHeight)
                .clipped()

                hinge.frame(height: hingeGap)

                Group {
                    if swapHalves { overview } else { controls }
                }
                .frame(height: secondHeight)
                .clipped()
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }     // Display bleibt beim Backen an
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - Knick

    private var hinge: some View {
        ZStack {
            Color.black.opacity(0.06)
            Capsule().fill(.quaternary).frame(width: 44, height: 4)
        }
    }

    // MARK: - Obere Hälfte: Übersicht

    private var overview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title2.bold()).lineLimit(1)
                Spacer()
                Text("\(totalBaked)/\(totalOrders)")
                    .font(.title.bold()).monospacedDigit()
                    .foregroundStyle(totalOrders > 0 && totalBaked == totalOrders ? Color.green : Color.primary)
            }
            Text("\(roundCount) round · \(detroitCount) Detroit")
                .font(.subheadline).foregroundStyle(.secondary)

            ScrollView {
                switch topMode {
                case .pizzas: pizzaCards
                case .guests: guestCards
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var pizzaCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
            ForEach(ordered) { pizza in
                PizzaOrderCard(pizza: pizza, baked: min(baked[pizza.persistentModelID] ?? 0, pizza.orderCount))
                    .onTapGesture {
                        // Antippen = eine Pizza gebacken; nach der letzten wieder bei 0
                        let done = baked[pizza.persistentModelID] ?? 0
                        baked[pizza.persistentModelID] = done >= pizza.orderCount ? 0 : done + 1
                    }
            }
            if ordered.isEmpty {
                Text("No orders yet.").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 24)
            }
        }
        .padding(.bottom, 8)
    }

    private var guestCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
            ForEach(orders) { order in
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.guest).font(.headline)
                    ForEach(order.lines.indices, id: \.self) { index in
                        let line = order.lines[index]
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(line.count)× \(line.custom == nil ? line.name : String(localized: "Custom pizza"))")
                                .font(.title3.weight(.semibold))
                            if let custom = line.custom {
                                Text(custom.map(\.name).joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary)
                            }
                            if !line.without.isEmpty {
                                Text("without \(line.without.joined(separator: ", "))").font(.subheadline).foregroundStyle(.red)
                            }
                            if let extra = line.extra, !extra.isEmpty {
                                Text("+ \(extra.joined(separator: ", "))").font(.subheadline).foregroundStyle(.green)
                            }
                        }
                    }
                    if let note = order.note, !note.isEmpty {
                        Text(note).font(.footnote).italic().foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.background, in: RoundedRectangle(cornerRadius: 14))
            }
            if orders.isEmpty {
                Text("Fetch the guest orders below to see who ordered what.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.top, 24)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Untere Hälfte: Bedienung

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Show on top", selection: $topMode) {
                    Text("By pizza").tag(TopMode.pizzas)
                    Text("By guest").tag(TopMode.guests)
                }
                .pickerStyle(.segmented)
                Menu {
                    Toggle("Swap top and bottom", isOn: $swapHalves)
                    Picker("Gap for the fold", selection: $hingeGap) {
                        Text("None").tag(0.0)
                        Text("Small").tag(24.0)
                        Text("Large").tag(48.0)
                    }
                    Button("Reset baked", systemImage: "arrow.counterclockwise") { baked = [:] }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                }
                Button("Done") { dismiss() }.bold()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            List {
                Section {
                    Button("Fetch guest orders", systemImage: "icloud.and.arrow.down") { Task { await fetch() } }
                        .disabled(isBusy || eventID.isEmpty)
                    if !status.isEmpty {
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(onMenu) { pizza in
                        MenuPizzaRow(pizza: pizza, number: nil, showsOrders: true) {}
                    }
                } header: {
                    Text("Orders")
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func fetch() async {
        isBusy = true; defer { isBusy = false }
        let service = GuestOrderService(project: project.trimmingCharacters(in: .whitespaces),
                                        apiKey: apiKey.trimmingCharacters(in: .whitespaces))
        do {
            orders = try await service.fetchOrders(id: eventID)
            if !orders.isEmpty {
                MenuPizza.apply(orders: orders, to: onMenu.filter { !$0.isGuestCustom }, context: modelContext)
                try? modelContext.save()
                topMode = .guests
            }
            status = String(localized: "\(orders.count) orders received.")
        } catch {
            status = error.localizedDescription
        }
    }
}

/// Große Karte für eine bestellte Pizza: Anzahl, Name, Sonderwünsche
private struct PizzaOrderCard: View {
    var pizza: MenuPizza
    var baked: Int

    private var isDone: Bool { baked >= pizza.orderCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(pizza.orderCount)×").font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                Spacer()
                if baked > 0 {
                    Label("\(baked)", systemImage: isDone ? "checkmark.circle.fill" : "flame")
                        .font(.headline).foregroundStyle(isDone ? .green : .orange)
                }
            }
            Text(pizza.name).font(.title3.weight(.semibold)).lineLimit(2)
            if pizza.isDetroit {
                Text("Detroit (pan)").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(pizza.removedToppings.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                if item.value > 0 {
                    Text("\(item.value)× without \(item.key)").font(.subheadline).foregroundStyle(.red)
                }
            }
            ForEach(pizza.guestExtras.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                if item.value > 0 {
                    Text("\(item.value)× + \(item.key)").font(.subheadline).foregroundStyle(.green)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .opacity(isDone ? 0.45 : 1)
        .contentShape(Rectangle())
    }
}

#Preview {
    OrdersFoldView()
}
